package Kernel::System::BWBTicketIntake;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBFieldMode',
    'Kernel::System::BWBTicketStore',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::Email',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {
        CreatingIntake => 0,
    }, $Type;
}

sub IsCreatingIntake {
    my ($Self) = @_;
    return $Self->{CreatingIntake} ? 1 : 0;
}

sub IsSupervisorNotifySkipped {
    my ($Self) = @_;
    return $Self->{SkipSupervisorNotify} ? 1 : 0;
}

sub Create {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(UserID CustomerID CustomerUser Title Body QueueID PriorityID Origin)) {
        return if !$Param{$Needed};
    }

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Origin = $Param{Origin};
    return if $Origin ne 'phone' && $Origin ne 'email' && $Origin ne 'field';

    my $CustomerID   = $Param{CustomerID};
    my $CustomerUser = $Param{CustomerUser};
    my $Title        = $Param{Title};
    my $Body         = $Param{Body};
    $Title =~ s/^\s+|\s+$//g;
    $Body  =~ s/^\s+|\s+$//g;
    return if !$Title || !$Body;

    return if !$Access->CustomerUserAccessCheck(
        UserID            => $Param{UserID},
        CustomerUserLogin => $CustomerUser,
    );

    my %Customer = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $CustomerUser,
    );
    return if !%Customer;

    my $UserCustomerID = $Customer{UserCustomerID} || $Customer{CustomerID} || '';
    return if $UserCustomerID ne $CustomerID;

    my %ValidPriorities = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList( Valid => 1 );
    return if !$ValidPriorities{ $Param{PriorityID} };

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserID       = $Param{UserID};
    my $OwnerID      = $Param{OwnerID} // 1;
    my $Lock         = $Param{Lock}    // 'unlock';

    $Self->{CreatingIntake}         = 1;
    $Self->{SkipSupervisorNotify}   = $Param{SendDeclaration} ? 1 : 0;
    my $TicketID = $TicketObject->TicketCreate(
        Title        => $Title,
        QueueID      => $Param{QueueID},
        Lock         => $Lock,
        PriorityID   => $Param{PriorityID},
        State        => 'open',
        CustomerID   => $CustomerID,
        CustomerUser => $CustomerUser,
        OwnerID      => $OwnerID,
        UserID       => $UserID,
    );
    $Self->{CreatingIntake}       = 0;
    $Self->{SkipSupervisorNotify} = 0;
    return if !$TicketID;

    $Kernel::OM->Get('Kernel::System::BWBTicketStore')->EnsureFromCustomerUser(
        TicketID => $TicketID,
        UserID   => $UserID,
    );

    my $FromName = join(
        ' ',
        grep {$_} ( $Customer{UserFirstname}, $Customer{UserLastname} )
    ) || $Customer{UserFullname} || $CustomerUser;
    my $FromEmail = $Customer{UserEmail} || '';
    my $From      = $FromEmail ? "$FromName <$FromEmail>" : $FromName;

    my $To = $Self->_QueueAddress( QueueID => $Param{QueueID} );

    my $ChannelName = $Origin eq 'phone' ? 'Phone' : 'Email';
    my $ArticleBackend = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
        ChannelName => $ChannelName,
    );

    my %ArticleParam = (
        TicketID             => $TicketID,
        SenderType           => 'customer',
        IsVisibleForCustomer => 1,
        Subject              => $Title,
        Body                 => $Body,
        From                 => $From,
        To                   => $To,
        UserID               => $UserID,
    );

    if ( $ChannelName eq 'Phone' ) {
        $ArticleParam{MimeType} = 'text/plain';
        $ArticleParam{Charset}  = 'utf-8';
    }
    else {
        $ArticleParam{ContentType} = 'text/plain; charset=utf-8';
    }

    if ( $Origin eq 'phone' ) {
        $ArticleParam{HistoryType}    = 'PhoneCallCustomer';
        $ArticleParam{HistoryComment} = 'Pedido registado por telefone em nome do cliente';
    }
    elsif ( $Origin eq 'field' ) {
        $ArticleParam{HistoryType}    = 'EmailCustomer';
        $ArticleParam{HistoryComment} = 'Ticket criado no modo de campo em nome do cliente';
    }
    else {
        $ArticleParam{HistoryType}    = 'EmailCustomer';
        $ArticleParam{HistoryComment} = 'Pedido registado por e-mail em nome do cliente';
    }

    my $ArticleID = $ArticleBackend->ArticleCreate(%ArticleParam);
    return if !$ArticleID;

    if ( $Param{SendDeclaration} ) {
        if (
            !$Self->_SendDeclarationEmails(
                TicketID          => $TicketID,
                UserID            => $UserID,
                Origin            => $Origin,
                Title             => $Title,
                Body              => $Body,
                CustomerFirstname => $Customer{UserFirstname},
                CustomerLastname  => $Customer{UserLastname},
                CustomerFullname  => $Customer{UserFullname},
                CustomerLogin     => $Customer{UserLogin} || $CustomerUser,
                CustomerEmail     => $Customer{UserEmail},
            )
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "BWBTicketIntake: ticket $TicketID criado, mas a declaração por e-mail falhou.",
            );
        }
    }

    return $TicketID;
}

sub CustomersForAgent {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID};

    my $Access  = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Company = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my %Seen;
    my @Customers;
    my $CustomerIDs = $Access->CustomerIDsGet( UserID => $Param{UserID} ) || [];
    for my $CustomerID ( @{$CustomerIDs} ) {
        next if !$CustomerID || $Seen{$CustomerID}++;
        next if !$Access->CustomerAccessCheck(
            UserID     => $Param{UserID},
            CustomerID => $CustomerID,
        );
        my %Data = $Company->CustomerCompanyGet( CustomerID => $CustomerID );
        my $Name = $Data{CustomerCompanyName} || $CustomerID;
        push @Customers, {
            CustomerID => $CustomerID,
            Label      => "$CustomerID | $Name",
        };
    }

    for my $User ( @{ $Self->CustomerUsersForAgent( UserID => $Param{UserID} ) } ) {
        my $CustomerID = $User->{CustomerID} || next;
        next if $Seen{$CustomerID}++;
        my %Data = $Company->CustomerCompanyGet( CustomerID => $CustomerID );
        my $Name = $Data{CustomerCompanyName} || $CustomerID;
        push @Customers, {
            CustomerID => $CustomerID,
            Label      => "$CustomerID | $Name",
        };
    }

    @Customers = sort { lc( $a->{Label} ) cmp lc( $b->{Label} ) } @Customers;
    return \@Customers;
}

sub CustomerUsersForAgent {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID};

    my $Access      = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $DB          = $Kernel::OM->Get('Kernel::System::DB');
    my $CustomerIDs = $Access->CustomerIDsGet( UserID => $Param{UserID} ) || [];

    my @Users;
    my @Candidates;

    if ( @{$CustomerIDs} ) {
        my $Placeholders = join ',', map {'?'} @{$CustomerIDs};
        my @Bind = map { \$_ } @{$CustomerIDs};
        if (
            $DB->Prepare(
                SQL => "SELECT login, first_name, last_name, email, customer_id FROM customer_user WHERE valid_id = 1 AND customer_id IN ($Placeholders) ORDER BY customer_id, last_name, first_name",
                Bind => \@Bind,
            )
            )
        {
            while ( my ( $Login, $First, $Last, $Email, $CustomerID ) = $DB->FetchrowArray() ) {
                push @Candidates, [ $Login, $First, $Last, $Email, $CustomerID ];
            }
        }
    }

    if (
        $DB->Prepare(
            SQL => q{
                SELECT cu.login, cu.first_name, cu.last_name, cu.email, cu.customer_id
                FROM customer_user cu
                INNER JOIN bwb_collaborator_store cs ON cs.store_id = cu.bwb_store_id AND cs.user_id = ?
                WHERE cu.valid_id = 1
                ORDER BY cu.customer_id, cu.last_name, cu.first_name
            },
            Bind => [ \$Param{UserID} ],
        )
        )
    {
        while ( my ( $Login, $First, $Last, $Email, $CustomerID ) = $DB->FetchrowArray() ) {
            push @Candidates, [ $Login, $First, $Last, $Email, $CustomerID ];
        }
    }

    my %Seen;
    for my $Row (@Candidates) {
        my ( $Login, $First, $Last, $Email, $CustomerID ) = @{$Row};
        next if !$Login || $Seen{$Login}++;
        next if !$Access->CustomerUserAccessCheck(
            UserID            => $Param{UserID},
            CustomerUserLogin => $Login,
        );
        my $Name = join( ' ', grep {$_} ( $First, $Last ) ) || $Login;
        push @Users, {
            Login      => $Login,
            Email      => $Email || '',
            CustomerID => $CustomerID,
            Label      => $Email ? "$Name ($Email)" : $Name,
        };
    }

    return \@Users;
}

sub CustomerUsersForCustomer {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID} || !$Param{CustomerID};

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    return [] if !$Access->CustomerAccessCheck(
        UserID     => $Param{UserID},
        CustomerID => $Param{CustomerID},
    );

    my $All = $Self->CustomerUsersForAgent( UserID => $Param{UserID} ) || [];
    return [
        grep { ( $_->{CustomerID} // '' ) eq $Param{CustomerID} }
        @{$All}
    ];
}

sub PrioritiesForForm {
    my ($Self) = @_;
    my %List = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList( Valid => 1 );
    my @Priorities;
    for my $ID ( sort { $a <=> $b } keys %List ) {
        push @Priorities, {
            PriorityID => $ID,
            Name       => $List{$ID},
            Selected   => 0,
        };
    }
    $Priorities[-1]{Selected} = 1 if @Priorities;
    return \@Priorities;
}

sub QueuesForAgent {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID};

    my %Queues = $Kernel::OM->Get('Kernel::System::Queue')->GetAllQueues(
        UserID => $Param{UserID},
        Type   => 'create',
    );
    my @List;
    for my $QueueID ( sort { $Queues{$a} cmp $Queues{$b} } keys %Queues ) {
        push @List, {
            QueueID => $QueueID,
            Name    => $Queues{$QueueID},
        };
    }
    return \@List;
}

sub DefaultQueueID {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};

    my $FieldMode = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
    my $QueueName = $FieldMode->DefaultQueueName( UserID => $Param{UserID} );
    my $QueueID   = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( Queue => $QueueName );
    return $QueueID if $QueueID;

    my $Queues = $Self->QueuesForAgent( UserID => $Param{UserID} );
    return $Queues->[0]->{QueueID} if $Queues && @{$Queues};
    return;
}

sub _QueueAddress {
    my ( $Self, %Param ) = @_;
    my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $Param{QueueID} );
    return 'Helpdesk <helpdesk@bwb.pt>' if !%Queue;

    if ( $Queue{SystemAddressID} ) {
        my %Address = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
            ID => $Queue{SystemAddressID},
        );
        if ( $Address{Name} ) {
            return $Address{Realname}
                ? "$Address{Realname} <$Address{Name}>"
                : $Address{Name};
        }
    }
    return $Queue{Email} ? "Helpdesk <$Queue{Email}>" : 'Helpdesk <helpdesk@bwb.pt>';
}

sub _QueueFromParts {
    my ( $Self, %Param ) = @_;
    my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $Param{QueueID} );
    my ( $From, $Realname, $Email ) = ( '', 'Helpdesk', '' );

    if ( $Queue{SystemAddressID} ) {
        my %Address = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
            ID => $Queue{SystemAddressID},
        );
        $Realname = $Address{Realname} || $Realname;
        $Email    = $Address{Name}     || $Email;
    }
    $Email ||= $Queue{Email} || 'helpdesk@bwb.pt';
    $From = $Realname ? "$Realname <$Email>" : $Email;
    return ( $From, $Realname, $Email );
}

sub _SendDeclarationEmails {
    my ( $Self, %Param ) = @_;
    my $TicketID = $Param{TicketID} || return;
    my $UserID   = $Param{UserID}   || return;
    my $Origin   = $Param{Origin}   || return;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;

    my %Actor = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $UserID );
    my $ActorName = $Actor{UserFullname} || $Actor{UserLogin} || '-';

    my $CustomerCompany = $Ticket{CustomerCompanyName} || $Ticket{CustomerID} || '-';
    if ( $Ticket{CustomerID} && !$Ticket{CustomerCompanyName} ) {
        my %Company = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $Ticket{CustomerID},
        );
        $CustomerCompany = $Company{CustomerCompanyName} || $CustomerCompany;
    }

    my $UserName = join(
        ' ',
        grep {$_} ( $Param{CustomerFirstname}, $Param{CustomerLastname} )
    ) || $Param{CustomerFullname} || $Param{CustomerLogin} || '-';
    my $UserEmail = $Param{CustomerEmail} || '';
    my $UserLabel = $UserEmail ? "$UserName ($UserEmail)" : $UserName;

    my $OriginLabel = $Origin eq 'phone' ? 'Via telefone' : 'Via e-mail';

    my $TicketNumber = $Ticket{TicketNumber} || '';
    my $Title        = $Param{Title} || $Ticket{Title} || '';
    my $Body         = $Param{Body}  || '';

    my ( $From, $FromRealname, $FromEmail ) = $Self->_QueueFromParts( QueueID => $Ticket{QueueID} );

    my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $Escape    = sub {
        my $Text = $HTMLUtils->ToHTML( String => defined $_[0] ? $_[0] : '' );
        $Text =~ s/\n/<br>\n/g;
        return $Text;
    };

    my $IdentityBlock = ''
        . '<p><b>Cliente:</b> ' . $Escape->($CustomerCompany) . '<br>'
        . '<b>Utilizador de cliente:</b> ' . $Escape->($UserLabel) . '<br>'
        . '<b>Registado por:</b> ' . $Escape->($ActorName) . '<br>'
        . '<b>Origem do pedido:</b> ' . $Escape->($OriginLabel) . '</p>';

    my $RequestBlock = ''
        . '<p><b>Título:</b> ' . $Escape->($Title) . '</p>'
        . '<p><b>Pedido:</b><br>' . $Escape->($Body) . '</p>';

    if ($UserEmail) {
        my $CustomerSubject = "Nova ocorrência registada em seu nome | Ticket#$TicketNumber";
        $CustomerSubject =~ s/[\r\n]+/ /g;

        my $CustomerIntro = '<p>O Helpdesk registou a seguinte ocorrência em seu nome:</p>';
        my $CustomerHTML  = $Self->_EmailShell(
            Heading => 'Nova ocorrência registada em seu nome',
            Body    => $CustomerIntro . $IdentityBlock . $RequestBlock,
        );

        my $ArticleBackend = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
            ChannelName => 'Email',
        );
        my $ArticleID = $ArticleBackend->ArticleSend(
            TicketID             => $TicketID,
            SenderType           => 'system',
            IsVisibleForCustomer => 1,
            From                 => $From,
            To                   => $UserEmail,
            Subject              => $CustomerSubject,
            Body                 => $CustomerHTML,
            MimeType             => 'text/html',
            Charset              => 'utf-8',
            UserID               => $UserID,
            HistoryType          => 'SendCustomerNotification',
            HistoryComment       => "\%\%$UserEmail",
            BWBSource            => 'intake',
        );
        return if !$ArticleID;
    }

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $ResponsibleUserID = $Access->ResponsibleUserIDGet( UserID => $UserID ) || $UserID;
    if ( int($ResponsibleUserID) != int($UserID) ) {
        my %Responsible = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $ResponsibleUserID,
        );
        if ( $Responsible{UserEmail} ) {
            my $Config = $Kernel::OM->Get('Kernel::Config');
            my $Link   = ( $Config->Get('HttpType') || 'https' ) . '://'
                . ( $Config->Get('FQDN') || 'helpdesk.storesace.cv' )
                . '/otobo/index.pl?Action=AgentTicketZoom;TicketID='
                . $TicketID;

            my $RespSubject = "Nova ocorrência registada | Ticket#$TicketNumber";
            $RespSubject =~ s/[\r\n]+/ /g;

            my $RespHTML = $Self->_EmailShell(
                Heading => 'Nova ocorrência registada',
                Body    => '<p>Foi registada uma nova ocorrência:</p>'
                    . $IdentityBlock
                    . $RequestBlock
                    . '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:28px 0"><tr><td style="border-radius:7px;background:#3a3a3c">'
                    . '<a href="' . $Escape->($Link) . '" style="display:inline-block;color:#fff;padding:14px 22px;text-decoration:none;font-weight:bold">Abrir o ticket</a>'
                    . '</td></tr></table>',
            );

            my $Sent = $Kernel::OM->Get('Kernel::System::Email')->Send(
                From      => $From,
                ReplyTo   => $From,
                To        => $Responsible{UserEmail},
                Subject   => $RespSubject,
                Charset   => 'utf-8',
                MimeType  => 'text/html',
                Body      => $RespHTML,
                TicketID  => $TicketID,
                BWBSource => 'intake',
            );
            if ( !$Sent || !$Sent->{Success} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "BWBTicketIntake: falha a notificar o responsável do ticket $TicketID.",
                );
            }
        }
    }

    return 1;
}

sub _EmailShell {
    my ( $Self, %Param ) = @_;
    my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $Heading   = $HTMLUtils->ToHTML( String => $Param{Heading} || '' );
    my $Body      = $Param{Body} || '';
    return '<!doctype html><html><body style="margin:0;background:#f5f5f7">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f5f7"><tr><td style="padding:24px 12px">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;margin:auto;background:#fff;border:1px solid #d2d2d7;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;color:#1d1d1f">'
        . '<tr><td style="padding:24px;background:#e5e5e7"><div style="font-size:13px;color:#6e6e73;margin-bottom:8px">Helpdesk</div>'
        . '<h1 style="margin:0;font-size:22px;color:#1d1d1f">' . $Heading . '</h1></td></tr>'
        . '<tr><td style="padding:28px;font-size:15px;line-height:1.5">' . $Body . '</td></tr>'
        . '<tr><td style="padding:18px 28px;border-top:1px solid #d2d2d7;background:#f5f5f7;color:#6e6e73;font-size:12px">Helpdesk — StoresAce</td></tr>'
        . '</table></td></tr></table></body></html>';
}

1;
