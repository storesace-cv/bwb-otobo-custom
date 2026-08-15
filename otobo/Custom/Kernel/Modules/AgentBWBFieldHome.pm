package Kernel::Modules::AgentBWBFieldHome;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Layout     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $FieldMode  = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
    my $Access     = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Ticket     = $Kernel::OM->Get('Kernel::System::Ticket');
    my $Subaction  = $Self->{Subaction} || $Request->GetParam( Param => 'Subaction' ) || '';

    if ( $Subaction eq 'Bootstrap' ) {
        return $Self->_JSON(
            Layout    => $Layout,
            Data      => {
                Success      => 1,
                Collaborator => $FieldMode->IsCollaborator( UserID => $Self->{UserID} ) ? 1 : 0,
                Preference   => $FieldMode->PreferenceGet( UserID => $Self->{UserID} ),
            },
        );
    }

    if ( $Subaction eq 'SetMode' ) {
        $Layout->ChallengeTokenCheck();
        my $Mode = $Request->GetParam( Param => 'Mode' ) || '';
        my $On   = ( $Mode eq 'field' || $Mode eq '1' ) ? 1 : 0;
        $FieldMode->PreferenceSet( UserID => $Self->{UserID}, Value => $On );
        return $Self->_JSON(
            Layout => $Layout,
            Data   => { Success => 1, Mode => $On ? 'field' : 'mobile' },
        );
    }

    if ( $Subaction eq 'StoreTicket' ) {
        $Layout->ChallengeTokenCheck();
        return $Self->_StoreTicket( Layout => $Layout, Request => $Request, FieldMode => $FieldMode, Access => $Access, Ticket => $Ticket );
    }

    my %Data = (
        Collaborator => $FieldMode->IsCollaborator( UserID => $Self->{UserID} ) ? 1 : 0,
        View         => 'home',
    );

    if ( $Subaction eq 'StartWork' ) {
        $Data{View}    = 'tickets';
        $Data{Tickets} = $Self->_OpenTicketsForOwner();
    }
    elsif ( $Subaction eq 'NewTicket' ) {
        $Data{View}          = 'create';
        $Data{Customers}     = $Self->_CustomersForAgent();
        $Data{CustomerUsers} = $Self->_CustomerUsersForAgent();
        $Data{Error}         = $Request->GetParam( Param => 'Error' ) || '';
    }
    else {
        $Data{OpenTickets} = $Self->_OpenTicketsForOwner();
        $Data{OpenWork}    = $Self->_OpenWorkSessions();
    }

    my $Output = $Layout->Header( Title => 'Painel de Controlo' );
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentBWBFieldHome',
        Data         => \%Data,
    );
    $Output .= $Layout->Footer();
    return $Output;
}

sub _JSON {
    my ( $Self, %Param ) = @_;
    my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode( Data => $Param{Data} );
    return $Param{Layout}->Attachment(
        ContentType => 'application/json; charset=utf-8',
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _OpenTicketsForOwner {
    my ($Self) = @_;
    my $Ticket = $Kernel::OM->Get('Kernel::System::Ticket');
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');

    my @IDs = $Ticket->TicketSearch(
        Result    => 'ARRAY',
        Limit     => 50,
        OwnerIDs  => [ $Self->{UserID} ],
        StateType => 'Open',
        UserID    => $Self->{UserID},
        Permission => 'ro',
    );

    my @Rows;
    for my $TicketID (@IDs) {
        next if !$Access->TicketAccessCheck( UserID => $Self->{UserID}, TicketID => $TicketID );
        my %T = $Ticket->TicketGet( TicketID => $TicketID, DynamicFields => 0, Silent => 1 );
        next if !%T;
        push @Rows, {
            TicketID     => $TicketID,
            TicketNumber => $T{TicketNumber},
            Title        => $T{Title},
            Customer     => $T{CustomerCompanyName} || $T{CustomerName} || $T{CustomerID} || '-',
            State        => $T{State},
        };
    }
    return \@Rows;
}

sub _OpenWorkSessions {
    my ($Self) = @_;
    my $DB     = $Kernel::OM->Get('Kernel::System::DB');
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Ticket = $Kernel::OM->Get('Kernel::System::Ticket');

    return [] if !$DB->Prepare(
        SQL => q{
            SELECT s.id, s.ticket_id, s.work_type, s.start_time, w.paused_at
            FROM bwb_work_session s
            LEFT JOIN bwb_work_sheet w ON w.session_id = s.id
            WHERE s.end_time IS NULL AND s.user_id = ?
            ORDER BY s.start_time DESC
        },
        Bind => [ \$Self->{UserID} ],
    );

    my @Rows;
    while ( my ( $SessionID, $TicketID, $WorkType, $StartUTC, $PausedAt ) = $DB->FetchrowArray() ) {
        next if !$Access->TicketAccessCheck( UserID => $Self->{UserID}, TicketID => $TicketID );
        my %T = $Ticket->TicketGet( TicketID => $TicketID, DynamicFields => 0, Silent => 1 );
        next if !%T;
        push @Rows, {
            SessionID    => $SessionID,
            TicketID     => $TicketID,
            TicketNumber => $T{TicketNumber},
            Title        => $T{Title},
            WorkType     => $WorkType,
            Status       => $PausedAt ? 'Em pausa' : 'Em execução',
            StatusClass  => $PausedAt ? 'BWBPaused' : 'BWBRunning',
        };
    }
    return \@Rows;
}

sub _CustomersForAgent {
    my ($Self) = @_;
    my $Access  = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Company = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my %Seen;
    my @Customers;
    my $CustomerIDs = $Access->CustomerIDsGet( UserID => $Self->{UserID} ) || [];
    for my $CustomerID ( @{$CustomerIDs} ) {
        next if !$CustomerID || $Seen{$CustomerID}++;
        next if !$Access->CustomerAccessCheck( UserID => $Self->{UserID}, CustomerID => $CustomerID );
        my %Data = $Company->CustomerCompanyGet( CustomerID => $CustomerID );
        my $Name = $Data{CustomerCompanyName} || $CustomerID;
        push @Customers, {
            CustomerID => $CustomerID,
            Name       => $Name,
            Label      => "$CustomerID | $Name",
        };
    }

    # Companies reachable only via store assignment (from known users).
    for my $User ( @{ $Self->_CustomerUsersForAgent() } ) {
        my $CustomerID = $User->{CustomerID} || next;
        next if $Seen{$CustomerID}++;
        my %Data = $Company->CustomerCompanyGet( CustomerID => $CustomerID );
        my $Name = $Data{CustomerCompanyName} || $CustomerID;
        push @Customers, {
            CustomerID => $CustomerID,
            Name       => $Name,
            Label      => "$CustomerID | $Name",
        };
    }

    @Customers = sort { lc( $a->{Label} ) cmp lc( $b->{Label} ) } @Customers;
    return \@Customers;
}

sub _CustomerUsersForAgent {
    my ($Self) = @_;
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $DB     = $Kernel::OM->Get('Kernel::System::DB');
    my $CustomerIDs = $Access->CustomerIDsGet( UserID => $Self->{UserID} ) || [];

    my @Users;
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
                next if !$Access->CustomerUserAccessCheck(
                    UserID            => $Self->{UserID},
                    CustomerUserLogin => $Login,
                );
                my $Name = join( ' ', grep {$_} ( $First, $Last ) ) || $Login;
                push @Users, {
                    Login      => $Login,
                    Name       => $Name,
                    Email      => $Email || '',
                    CustomerID => $CustomerID,
                    Label      => "$Name <$Login>",
                };
            }
        }
    }

    # Also include users reachable only via store assignment.
    if (
        $DB->Prepare(
            SQL => q{
                SELECT cu.login, cu.first_name, cu.last_name, cu.email, cu.customer_id
                FROM customer_user cu
                INNER JOIN bwb_collaborator_store cs ON cs.store_id = cu.bwb_store_id AND cs.user_id = ?
                WHERE cu.valid_id = 1
                ORDER BY cu.customer_id, cu.last_name, cu.first_name
            },
            Bind => [ \$Self->{UserID} ],
        )
        )
    {
        my %Seen = map { $_->{Login} => 1 } @Users;
        while ( my ( $Login, $First, $Last, $Email, $CustomerID ) = $DB->FetchrowArray() ) {
            next if $Seen{$Login}++;
            next if !$Access->CustomerUserAccessCheck(
                UserID            => $Self->{UserID},
                CustomerUserLogin => $Login,
            );
            my $Name = join( ' ', grep {$_} ( $First, $Last ) ) || $Login;
            push @Users, {
                Login      => $Login,
                Name       => $Name,
                Email      => $Email || '',
                CustomerID => $CustomerID,
                Label      => "$Name <$Login>",
            };
        }
    }

    return \@Users;
}

sub _StoreTicket {
    my ( $Self, %Param ) = @_;
    my $Layout    = $Param{Layout};
    my $Request   = $Param{Request};
    my $FieldMode = $Param{FieldMode};
    my $Access    = $Param{Access};
    my $Ticket    = $Param{Ticket};

    my $CustomerID   = $Request->GetParam( Param => 'CustomerID' )   || '';
    my $CustomerUser = $Request->GetParam( Param => 'CustomerUser' ) || '';
    my $Title        = $Request->GetParam( Param => 'Title' )        || '';
    my $Body         = $Request->GetParam( Param => 'Body' )         || '';
    $Title =~ s/^\s+|\s+$//g;
    $Body  =~ s/^\s+|\s+$//g;

    my $Fail = sub {
        my ($Msg) = @_;
        return $Layout->Redirect(
            OP => 'Action=AgentBWBFieldHome;Subaction=NewTicket;Error=' . $Layout->LinkEncode($Msg),
        );
    };

    return $Fail->('Indique o cliente.')               if !$CustomerID;
    return $Fail->('Indique o utilizador de cliente.') if !$CustomerUser;
    return $Fail->('Indique o título.')                if !$Title;
    return $Fail->('Descreva o problema.')             if !$Body;
    return $Fail->('Sem permissão para este cliente.')
        if !$Access->CustomerAccessCheck(
            UserID     => $Self->{UserID},
            CustomerID => $CustomerID,
        )
        && !$Access->CustomerUserAccessCheck(
            UserID            => $Self->{UserID},
            CustomerUserLogin => $CustomerUser,
        );
    return $Fail->('Sem permissão para este utilizador de cliente.')
        if !$Access->CustomerUserAccessCheck(
            UserID            => $Self->{UserID},
            CustomerUserLogin => $CustomerUser,
        );

    my %Customer = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $CustomerUser,
    );
    return $Fail->('Utilizador de cliente inválido.') if !%Customer;
    my $UserCustomerID = $Customer{UserCustomerID} || $Customer{CustomerID} || '';
    return $Fail->('O utilizador não pertence ao cliente escolhido.')
        if $UserCustomerID ne $CustomerID;

    my $QueueName = $FieldMode->DefaultQueueName( UserID => $Self->{UserID} );
    my $QueueID   = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( Queue => $QueueName );
    return $Fail->("Fila $QueueName indisponível.") if !$QueueID;

    my $TicketID = $Ticket->TicketCreate(
        Title        => $Title,
        QueueID      => $QueueID,
        Lock         => 'lock',
        Priority     => '3 normal',
        State        => 'open',
        CustomerID   => $CustomerID,
        CustomerUser => $CustomerUser,
        OwnerID      => $Self->{UserID},
        UserID       => $Self->{UserID},
    );
    return $Fail->('Não foi possível criar o ticket.') if !$TicketID;

    my $ArticleBackend = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
        ChannelName => 'Phone',
    );
    my $ArticleID = $ArticleBackend->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'agent',
        IsVisibleForCustomer => 1,
        Subject              => $Title,
        Body                 => $Body,
        ContentType          => 'text/plain; charset=utf-8',
        HistoryType          => 'AddNote',
        HistoryComment       => 'Ticket criado no modo de campo',
        From                 => $Layout->{UserFullname} || $Layout->{UserLogin},
        UserID               => $Self->{UserID},
    );
    return $Fail->('Ticket criado, mas o artigo falhou.') if !$ArticleID;

    return $Layout->Redirect( OP => 'Action=AgentBWBWorkSession;TicketID=' . $TicketID );
}

1;
