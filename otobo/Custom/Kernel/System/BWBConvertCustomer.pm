package Kernel::System::BWBConvertCustomer;

use strict;
use warnings;
use utf8;
use Unicode::Normalize qw(NFD);

our @ObjectDependencies = qw(
    Kernel::System::BWBAccess
    Kernel::System::BWBStore
    Kernel::System::BWBTicketStore
    Kernel::System::CustomerCompany
    Kernel::System::CustomerUser
    Kernel::System::DB
    Kernel::System::Queue
    Kernel::System::Ticket
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Allowed {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID} || !$Param{UserID};

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID => $Param{TicketID}, DynamicFields => 0, Silent => 1,
    );
    return if !$Ticket{TicketID} || ( $Ticket{Queue} || '' ) ne 'zs-postmaster';
    return if !$Kernel::OM->Get('Kernel::System::Ticket')->TicketPermission(
        Type => 'rw', TicketID => $Param{TicketID}, UserID => $Param{UserID}, LogNo => 1,
    );
    return if ( $Kernel::OM->Get('Kernel::System::BWBAccess')->ResponsibleUserIDGet( UserID => $Param{UserID} ) || 0 ) != 4;
    return 1;
}

sub SenderGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID};
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL => q{SELECT adm.a_from FROM article a INNER JOIN article_data_mime adm ON adm.article_id = a.id WHERE a.ticket_id = ? AND a.article_sender_type_id = 3 ORDER BY a.id ASC},
        Bind => [ \$Param{TicketID} ], Limit => 1,
    );
    my @Row = $DBObject->FetchrowArray();
    return if !@Row;
    my ( $Name, $Email ) = $Self->_AddressParse( Address => $Row[0] );
    return { Name => $Name, Email => $Email, Raw => $Row[0] };
}

sub MatchingTicketIDsGet {
    my ( $Self, %Param ) = @_;
    my $Email = lc( $Param{Email} || '' );
    return [] if !$Email;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL => q{SELECT t.id, adm.a_from FROM ticket t INNER JOIN queue q ON q.id = t.queue_id INNER JOIN article a ON a.ticket_id = t.id INNER JOIN article_data_mime adm ON adm.article_id = a.id WHERE q.name = 'zs-postmaster' AND a.article_sender_type_id = 3 ORDER BY t.id, a.id},
    );
    my ( %Seen, @TicketIDs );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next if $Seen{ $Row[0] }++;
        my ( undef, $ArticleEmail ) = $Self->_AddressParse( Address => $Row[1] );
        push @TicketIDs, $Row[0] if lc( $ArticleEmail || '' ) eq $Email;
    }
    return \@TicketIDs;
}

sub CustomerIDSuggest {
    my ($Self) = @_;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 1000 if !$DBObject->Prepare(
        SQL => q{SELECT MAX(CAST(customer_id AS UNSIGNED)) FROM customer_company WHERE customer_id REGEXP '^[0-9]+$'},
    );
    my @Row = $DBObject->FetchrowArray();
    return ( $Row[0] || 999 ) + 1;
}

sub LoginSuggest {
    my ( $Self, %Param ) = @_;
    my $Base = lc join '.', grep { length } map { $Self->_ASCIIFold($_) } ( $Param{Firstname}, $Param{Lastname} );
    $Base =~ s/[^a-z0-9.]+//g;
    $Base =~ s/^\.+|\.+$//g;
    $Base ||= 'utilizador';
    my $Object = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $Login = $Base;
    my $Suffix = 2;
    while ( my %Existing = $Object->CustomerUserDataGet( User => $Login ) ) {
        $Login = $Base . $Suffix++;
    }
    return $Login;
}

sub Convert {
    my ( $Self, %Param ) = @_;
    for my $Required (qw(TicketID UserID CustomerID CustomerName Firstname Lastname UserLogin UserEmail)) {
        return { Success => 0, Error => "Campo obrigatório em falta: $Required" } if !defined $Param{$Required} || $Param{$Required} eq '';
    }
    return { Success => 0, Error => 'Operação não autorizada.' } if !$Self->Allowed(%Param);

    for my $Key (qw(CustomerID CustomerName Firstname Lastname UserLogin UserEmail CustomerStreet CustomerPhone StoreStreet)) {
        next if !defined $Param{$Key};
        $Param{$Key} =~ s/^\s+|\s+$//g;
    }
    $Param{UserEmail} = lc $Param{UserEmail};
    return { Success => 0, Error => 'O endereço de e-mail não é válido.' }
        if $Param{UserEmail} !~ /^[^\s\@]+\@[^\s\@]+\.[^\s\@]+$/;
    my $OriginalSender = $Self->SenderGet( TicketID => $Param{TicketID} ) || {};
    return { Success => 0, Error => 'O e-mail não corresponde ao remetente original deste ticket.' }
        if lc( $OriginalSender->{Email} || '' ) ne $Param{UserEmail};

    my $CompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %Company = $CompanyObject->CustomerCompanyGet( CustomerID => $Param{CustomerID} );
    return { Success => 0, Error => 'O número de cliente já existe.' } if %Company;
    my %Login = $UserObject->CustomerUserDataGet( User => $Param{UserLogin} );
    return { Success => 0, Error => 'O nome de utilizador já existe.' } if %Login;
    my %EmailMatch = $UserObject->CustomerSearch( Valid => 0, PostMasterSearch => $Param{UserEmail} );
    return { Success => 0, Error => 'Este e-mail já está associado a outro utilizador de cliente.' } if %EmailMatch;

    my $TicketIDs = $Self->MatchingTicketIDsGet( Email => $Param{UserEmail} );
    return { Success => 0, Error => 'Não foram encontrados tickets deste remetente na fila zs-postmaster.' } if !@{$TicketIDs};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return { Success => 0, Error => 'Não foi possível estabelecer ligação à base de dados.' } if !$DBObject->Ping();
    return { Success => 0, Error => 'Não foi possível iniciar a operação transacional.' } if !$DBObject->BeginWork();
    my $Success;
    eval {
        my $Comment = 'Criado através da conversão de remetente em cliente.';
        $Comment .= "\nTelefone: $Param{CustomerPhone}" if $Param{CustomerPhone};
        my $Created = $CompanyObject->CustomerCompanyAdd(
            CustomerID => $Param{CustomerID}, CustomerCompanyName => $Param{CustomerName},
            CustomerCompanyStreet => $Param{CustomerStreet} || '', CustomerCompanyZIP => '',
            CustomerCompanyCity => 'Luanda', CustomerCompanyCountry => 'Angola',
            CustomerCompanyURL => '', CustomerCompanyComment => $Comment, ValidID => 1, UserID => $Param{UserID},
        );
        die "Não foi possível criar o cliente.\n" if !$Created;

        my $OwnerID = $Kernel::OM->Get('Kernel::System::BWBAccess')->ResponsibleUserIDGet( UserID => $Param{UserID} ) || $Param{UserID};
        die "Não foi possível atribuir o cliente ao agente responsável.\n" if !$Kernel::OM->Get('Kernel::System::BWBAccess')->CustomerOwnerSet(
            CustomerID => $Param{CustomerID}, OwnerUserID => $OwnerID, UserID => $Param{UserID},
        );
        my $StoreObject = $Kernel::OM->Get('Kernel::System::BWBStore');
        my $StoreID = $StoreObject->HeadquartersEnsure( CustomerID => $Param{CustomerID}, UserID => $Param{UserID} );
        die "Não foi possível criar a loja Sede.\n" if !$StoreID;
        if ( $Param{StoreStreet} && $Param{StoreStreet} ne ( $Param{CustomerStreet} || '' ) ) {
            die "Não foi possível guardar a morada da Sede.\n" if !$StoreObject->StoreUpdate(
                StoreID => $StoreID, CustomerID => $Param{CustomerID}, StoreNumber => 'S', StoreName => 'Sede',
                StoreStreet => $Param{StoreStreet}, ValidID => 1, UserID => $Param{UserID},
            );
        }

        my $CreatedUser = $UserObject->CustomerUserAdd(
            Source => 'CustomerUser', UserFirstname => $Param{Firstname}, UserLastname => $Param{Lastname},
            UserCustomerID => $Param{CustomerID}, UserLogin => $Param{UserLogin}, UserEmail => $Param{UserEmail},
            UserPhone => '', UserFax => '', UserMobile => '', UserStreet => $Param{StoreStreet} || $Param{CustomerStreet} || '',
            UserZip => '', UserCity => 'Luanda', UserCountry => 'Angola', UserComment => 'Criado através da conversão de remetente.',
            UserStoreID => $StoreID, ValidID => 1, UserID => $Param{UserID},
        );
        die "Não foi possível criar o utilizador do cliente.\n" if !$CreatedUser;

        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
        my @FlagUsers = $Self->_ZSUserIDsGet( CurrentUserID => $Param{UserID} );
        for my $TicketID ( @{$TicketIDs} ) {
            die "Falha ao associar o ticket $TicketID ao cliente.\n" if !$TicketObject->TicketCustomerSet(
                No => $Param{CustomerID}, User => $CreatedUser, TicketID => $TicketID, UserID => $Param{UserID},
            );
            die "Falha ao gravar a loja do ticket $TicketID.\n" if !$Kernel::OM->Get('Kernel::System::BWBTicketStore')->EnsureFromCustomerUser(
                TicketID    => $TicketID,
                UserID      => $Param{UserID},
                OnlyIfEmpty => 1,
            );
            die "Falha ao mover o ticket $TicketID.\n" if !$TicketObject->TicketQueueSet(
                Queue => 'zsangola-in', TicketID => $TicketID, UserID => $Param{UserID}, SendNoNotification => 1,
            );
            for my $FlagUserID (@FlagUsers) {
                die "Falha ao marcar o ticket $TicketID como não visto.\n" if !$TicketObject->TicketFlagSet(
                    TicketID => $TicketID, Key => 'Seen', Value => 0, UserID => $FlagUserID,
                );
            }
            die "Falha ao registar o histórico do ticket $TicketID.\n" if !$TicketObject->HistoryAdd(
                Name => "Remetente convertido no cliente $Param{CustomerID}; ticket associado e movido para zsangola-in.",
                HistoryType => 'Misc', TicketID => $TicketID, CreateUserID => $Param{UserID},
            );
        }
        $DBObject->{dbh}->commit() or die "Falha ao confirmar a operação.\n";
        $Success = 1;
    };
    my $Error = $@;
    if (!$Success) {
        eval { $DBObject->Rollback(); };
        return { Success => 0, Error => $Error || 'A operação foi anulada por segurança.' };
    }
    # Mail cleanup is deliberately executed after the database commit. A temporary
    # IMAP failure must never roll back an otherwise successful customer conversion.
    eval {
        $Kernel::OM->Get('Kernel::System::BWBZSIMAP')->PendingDeleteForTicketIDs(
            TicketIDs => $TicketIDs,
        );
    };
    if ($@) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ZS IMAP: conversão concluída, mas a limpeza de Helpdesk - Pendentes falhou: $@",
        );
    }
    return { Success => 1, TicketIDs => $TicketIDs, CustomerID => $Param{CustomerID}, UserLogin => $Param{UserLogin} };
}

sub _ZSUserIDsGet {
    my ( $Self, %Param ) = @_;
    my %IDs = map { $_ => 1 } grep {$_} ( 4, $Param{CurrentUserID} );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    if ( $DBObject->Prepare( SQL => q{SELECT user_id FROM bwb_agent_hierarchy WHERE responsible_user_id = 4} ) ) {
        while ( my @Row = $DBObject->FetchrowArray() ) { $IDs{ $Row[0] } = 1 if $Row[0]; }
    }
    return sort { $a <=> $b } keys %IDs;
}

sub _AddressParse {
    my ( $Self, %Param ) = @_;
    my $Raw = $Param{Address} || '';
    my ( $Name, $Email );
    if ( $Raw =~ /^\s*"?([^"<]*)"?\s*<\s*([^>\s]+\@[^>\s]+)\s*>/ ) { ( $Name, $Email ) = ( $1, $2 ); }
    elsif ( $Raw =~ /([^\s<>,;]+\@[^\s<>,;]+)/ ) { $Email = $1; $Name = $Raw; $Name =~ s/\Q$Email\E//; }
    $Name ||= '';
    $Name =~ s/^\s+|\s+$//g; $Name =~ s/^"|"$//g;
    $Email = lc( $Email || '' );
    return ( $Name, $Email );
}

sub _ASCIIFold {
    my ( $Self, $Text ) = @_;
    $Text = NFD( $Text || '' );
    $Text =~ s/\pM//g;
    return $Text;
}

1;
