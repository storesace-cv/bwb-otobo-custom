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
        my $Work     = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
        my $Sheet    = $Kernel::OM->Get('Kernel::System::BWBWorkSheet');
        my $Active   = $Work->ActiveGet( UserID => $Self->{UserID} );
        my $ActiveWork;
        if ($Active) {
            my $Draft = $Sheet->DraftGet( SessionID => $Active->{SessionID} ) || {};
            $ActiveWork = {
                TicketID  => $Active->{TicketID},
                SessionID => $Active->{SessionID},
                Paused    => $Draft->{PausedAt} ? 1 : 0,
            };
        }
        return $Self->_JSON(
            Layout => $Layout,
            Data   => {
                Success      => 1,
                Collaborator => $FieldMode->IsCollaborator( UserID => $Self->{UserID} ) ? 1 : 0,
                Preference   => $FieldMode->PreferenceGet( UserID => $Self->{UserID} ),
                ActiveWork   => $ActiveWork,
            },
        );
    }

    if ( $Subaction eq 'SetMode' ) {
        $Layout->ChallengeTokenCheck();
        # Field Mode is exclusively for collaborators (not responsible agents).
        if ( !$FieldMode->IsCollaborator( UserID => $Self->{UserID} ) ) {
            $FieldMode->PreferenceSet( UserID => $Self->{UserID}, Value => 0 );
            return $Self->_JSON(
                Layout => $Layout,
                Data   => { Success => 0, Mode => 'mobile', Collaborator => 0 },
            );
        }
        my $Mode = $Request->GetParam( Param => 'Mode' ) || '';
        my $On   = ( $Mode eq 'field' || $Mode eq '1' ) ? 1 : 0;
        $FieldMode->PreferenceSet( UserID => $Self->{UserID}, Value => $On );
        return $Self->_JSON(
            Layout => $Layout,
            Data   => { Success => 1, Mode => $On ? 'field' : 'mobile' },
        );
    }

    # Full Field Home UI is for collaborators only.
    if ( !$FieldMode->IsCollaborator( UserID => $Self->{UserID} ) ) {
        return $Layout->Redirect( OP => 'Action=AgentDashboard' );
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
        $Data{Customers}     = $Kernel::OM->Get('Kernel::System::BWBTicketIntake')->CustomersForAgent(
            UserID => $Self->{UserID},
        );
        $Data{CustomerUsers} = $Kernel::OM->Get('Kernel::System::BWBTicketIntake')->CustomerUsersForAgent(
            UserID => $Self->{UserID},
        );
        $Data{Priorities}    = $Kernel::OM->Get('Kernel::System::BWBTicketIntake')->PrioritiesForForm();
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
            Store        => $Kernel::OM->Get('Kernel::System::BWBTicketStore')->LabelGet(
                TicketID => $TicketID,
            ) || '-',
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

    # Drain the cursor before TicketAccessCheck/TicketGet — those reuse the same DB handle.
    my @Raw;
    while ( my ( $SessionID, $TicketID, $WorkType, $StartUTC, $PausedAt ) = $DB->FetchrowArray() ) {
        push @Raw, [ $SessionID, $TicketID, $WorkType, $StartUTC, $PausedAt ];
    }

    my @Rows;
    for my $Row (@Raw) {
        my ( $SessionID, $TicketID, $WorkType, $StartUTC, $PausedAt ) = @{$Row};
        next if !$Access->TicketAccessCheck( UserID => $Self->{UserID}, TicketID => $TicketID );
        my %T = $Ticket->TicketGet( TicketID => $TicketID, DynamicFields => 0, Silent => 1 );
        next if !%T;
        push @Rows, {
            SessionID    => $SessionID,
            TicketID     => $TicketID,
            TicketNumber => $T{TicketNumber},
            Title        => $T{Title},
            Customer     => $T{CustomerCompanyName} || $T{CustomerName} || $T{CustomerID} || '-',
            Store        => $Kernel::OM->Get('Kernel::System::BWBTicketStore')->LabelGet(
                TicketID => $TicketID,
            ) || '-',
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
            # Drain the cursor before CustomerUserAccessCheck — that call reuses the same DB handle.
            while ( my ( $Login, $First, $Last, $Email, $CustomerID ) = $DB->FetchrowArray() ) {
                push @Candidates, [ $Login, $First, $Last, $Email, $CustomerID ];
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
        while ( my ( $Login, $First, $Last, $Email, $CustomerID ) = $DB->FetchrowArray() ) {
            push @Candidates, [ $Login, $First, $Last, $Email, $CustomerID ];
        }
    }

    my %Seen;
    for my $Row (@Candidates) {
        my ( $Login, $First, $Last, $Email, $CustomerID ) = @{$Row};
        next if !$Login || $Seen{$Login}++;
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

    return \@Users;
}

sub _PrioritiesForForm {
    my ($Self) = @_;
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my %List = $PriorityObject->PriorityList( Valid => 1 );

    # Ordem por ID (nesta instalação: maior ID = maior urgência). Por defeito: a mais alta.
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

sub _StoreTicket {
    my ( $Self, %Param ) = @_;
    my $Layout    = $Param{Layout};
    my $Request   = $Param{Request};
    my $FieldMode = $Param{FieldMode};
    my $Access    = $Param{Access};
    my $Ticket    = $Param{Ticket};

    my $CustomerID   = $Request->GetParam( Param => 'CustomerID' )   || '';
    my $CustomerUser = $Request->GetParam( Param => 'CustomerUser' ) || '';
    my $PriorityID   = $Request->GetParam( Param => 'PriorityID' )   || '';
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
    return $Fail->('Indique a prioridade.')            if !$PriorityID || $PriorityID !~ m{\A\d+\z};
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

    my %ValidPriorities = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList( Valid => 1 );
    return $Fail->('Prioridade inválida.') if !$ValidPriorities{$PriorityID};

    my $QueueName = $FieldMode->DefaultQueueName( UserID => $Self->{UserID} );
    my $QueueID   = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( Queue => $QueueName );
    return $Fail->("Fila $QueueName indisponível.") if !$QueueID;

    my $TicketID = $Kernel::OM->Get('Kernel::System::BWBTicketIntake')->Create(
        UserID          => $Self->{UserID},
        CustomerID      => $CustomerID,
        CustomerUser    => $CustomerUser,
        QueueID         => $QueueID,
        PriorityID      => $PriorityID,
        Title           => $Title,
        Body            => $Body,
        Origin          => 'field',
        SendDeclaration => 0,
        OwnerID         => $Self->{UserID},
        Lock            => 'lock',
    );
    return $Fail->('Não foi possível criar o ticket.') if !$TicketID;

    # Folha obrigatória e já associada a este ticket (fluxo Field).
    my $Types = $Kernel::OM->Get('Kernel::System::BWBOperationType');
    my @Available = @{ $Types->AvailableList( UserID => $Self->{UserID} ) || [] };
    my $WorkType;
    for my $Item (@Available) {
        my $Name = $Item->{Name} || next;
        if ( $Name =~ m{presencial}i ) {
            $WorkType = $Name;
            last;
        }
    }
    $WorkType ||= $Available[0]->{Name} if @Available;
    return $Fail->('Ticket criado, mas não há tipo de intervenção disponível para abrir a folha.')
        if !$WorkType;

    my $Work  = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
    my $Sheet = $Kernel::OM->Get('Kernel::System::BWBWorkSheet');
    if (
        !$Work->Start(
            UserID    => $Self->{UserID},
            TicketID  => $TicketID,
            WorkType  => $WorkType,
            NoArticle => 1,
        )
        )
    {
        return $Fail->('Ticket criado, mas não foi possível abrir a folha de trabalho.');
    }
    my $Active = $Work->ActiveGet( UserID => $Self->{UserID} );
    if ( !$Active || int( $Active->{TicketID} ) != int($TicketID) ) {
        return $Fail->('Ticket criado, mas a folha não ficou associada a este ticket.');
    }
    my $FormID = 'BWBWork' . $Active->{SessionID};
    $Sheet->DraftSave(
        SessionID => $Active->{SessionID},
        UserID    => $Self->{UserID},
        Body      => '',
        FormID    => $FormID,
    );

    return $Layout->Redirect( OP => 'Action=AgentBWBWorkSession;TicketID=' . $TicketID );
}

1;
