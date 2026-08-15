package Kernel::System::BWBAccess;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Group',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub IsGlobalAdministrator {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID};

    my $Login = $Kernel::OM->Get('Kernel::System::User')->UserLookup( UserID => $Param{UserID} ) || '';
    return 1 if $Login eq 'admin' || $Login eq 'root@localhost';
    return 0;
}

sub ResponsibleUserIDGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT responsible_user_id FROM bwb_agent_hierarchy WHERE user_id = ?',
        Bind => [ \$Param{UserID} ],
    );
    my ($ResponsibleUserID) = $DBObject->FetchrowArray();
    return $ResponsibleUserID || $Param{UserID};
}

sub CustomerOwnerSet {
    my ( $Self, %Param ) = @_;
    return if !$Param{CustomerID} || !$Param{OwnerUserID} || !$Param{UserID};

    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            INSERT INTO bwb_customer_owner
                (customer_id, owner_user_id, create_time, create_by, change_time, change_by)
            VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)
            ON DUPLICATE KEY UPDATE owner_user_id = VALUES(owner_user_id),
                change_time = current_timestamp, change_by = VALUES(change_by)
        },
        Bind => [ \$Param{CustomerID}, \$Param{OwnerUserID}, \$Param{UserID}, \$Param{UserID} ],
    );
}

sub CustomerOwnerGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{CustomerID};
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT owner_user_id FROM bwb_customer_owner WHERE customer_id = ?',
        Bind => [ \$Param{CustomerID} ],
    );
    my ($OwnerUserID) = $DBObject->FetchrowArray();
    return $OwnerUserID;
}

sub CustomerAccessCheck {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID} || !$Param{CustomerID};
    return 1 if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );

    my $ResponsibleUserID = $Self->ResponsibleUserIDGet( UserID => $Param{UserID} );
    my $OwnerUserID = $Self->CustomerOwnerGet( CustomerID => $Param{CustomerID} );
    # Legacy tickets can contain an email address or no registered company as
    # CustomerID.  All pre-existing legacy data belongs to Jorge (UserID 2).
    $OwnerUserID ||= 2;
    return 1 if $ResponsibleUserID == $Param{UserID}
        && $OwnerUserID && $Param{UserID} == $OwnerUserID;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 0 if !$DBObject->Prepare(
        SQL => 'SELECT 1 FROM bwb_collaborator_customer WHERE user_id = ? AND customer_id = ?',
        Bind => [ \$Param{UserID}, \$Param{CustomerID} ],
    );
    my ($Allowed) = $DBObject->FetchrowArray();
    return $Allowed ? 1 : 0;
}

sub StoreAccessCheck {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID} || !$Param{StoreID};
    return 1 if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 0 if !$DBObject->Prepare(
        SQL => 'SELECT customer_id FROM bwb_store WHERE id = ?', Bind => [ \$Param{StoreID} ],
    );
    my ($CustomerID) = $DBObject->FetchrowArray();
    return 0 if !$CustomerID;
    return 1 if $Self->CustomerAccessCheck( UserID => $Param{UserID}, CustomerID => $CustomerID );

    return 0 if !$DBObject->Prepare(
        SQL => 'SELECT 1 FROM bwb_collaborator_store WHERE user_id = ? AND store_id = ?',
        Bind => [ \$Param{UserID}, \$Param{StoreID} ],
    );
    my ($Allowed) = $DBObject->FetchrowArray();
    return $Allowed ? 1 : 0;
}

sub CustomerUserAccessCheck {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID} || !$Param{CustomerUserLogin};
    return 1 if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 0 if !$DBObject->Prepare(
        SQL => 'SELECT customer_id, bwb_store_id FROM customer_user WHERE login = ?',
        Bind => [ \$Param{CustomerUserLogin} ],
    );
    my ( $CustomerID, $StoreID ) = $DBObject->FetchrowArray();
    return 0 if !$CustomerID;
    return 1 if $Self->CustomerAccessCheck( UserID => $Param{UserID}, CustomerID => $CustomerID );
    return $StoreID && $Self->StoreAccessCheck( UserID => $Param{UserID}, StoreID => $StoreID ) ? 1 : 0;
}

sub TicketAccessCheck {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID} || !$Param{TicketID};
    return 1 if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID => $Param{TicketID}, DynamicFields => 0, Silent => 1,
    );
    return 0 if !%Ticket;

    # The ZS operation owns both of its queues.  This deliberately precedes
    # customer checks because zs-postmaster contains senders that are not yet
    # registered as customer users.  Collaborators inherit the responsible
    # agent's queue scope.
    if ( ( $Ticket{Queue} // '' ) eq 'zsangola-in' || ( $Ticket{Queue} // '' ) eq 'zs-postmaster' ) {
        return $Self->ResponsibleUserIDGet( UserID => $Param{UserID} ) == 4 ? 1 : 0;
    }

    return 1 if $Ticket{CustomerID} && $Self->CustomerAccessCheck(
        UserID => $Param{UserID}, CustomerID => $Ticket{CustomerID},
    );
    return 1 if $Ticket{CustomerUserID} && $Self->CustomerUserAccessCheck(
        UserID => $Param{UserID}, CustomerUserLogin => $Ticket{CustomerUserID},
    );
    # Tickets históricos migrados sem uma referência válida de cliente pertencem
    # ao agente Jorge (UserID 2), conforme a atribuição inicial acordada.
    return $Self->ResponsibleUserIDGet( UserID => $Param{UserID} ) == 2 ? 1 : 0;
}

sub CustomerIDsGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    return if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );

    my $ResponsibleUserID = $Self->ResponsibleUserIDGet( UserID => $Param{UserID} );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $IsCollaborator = $ResponsibleUserID != $Param{UserID};
    my $SQL = $IsCollaborator
        ? 'SELECT customer_id FROM bwb_collaborator_customer WHERE user_id = ? ORDER BY customer_id'
        : 'SELECT customer_id FROM bwb_customer_owner WHERE owner_user_id = ? ORDER BY customer_id';
    my $BindID = $IsCollaborator ? $Param{UserID} : $ResponsibleUserID;
    return if !$DBObject->Prepare( SQL => $SQL, Bind => [ \$BindID ] );
    my @CustomerIDs;
    while ( my ($CustomerID) = $DBObject->FetchrowArray() ) {
        push @CustomerIDs, $CustomerID;
    }
    return \@CustomerIDs;
}

sub StoreIDsGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    return if $Self->IsGlobalAdministrator( UserID => $Param{UserID} );
    my $ResponsibleUserID = $Self->ResponsibleUserIDGet( UserID => $Param{UserID} );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my ( $SQL, $BindID );
    if ( $ResponsibleUserID == $Param{UserID} ) {
        $SQL = 'SELECT s.id FROM bwb_store s JOIN bwb_customer_owner o ON o.customer_id=s.customer_id WHERE o.owner_user_id=? ORDER BY s.id';
        $BindID = $Param{UserID};
    }
    else {
        $SQL = q{SELECT DISTINCT s.id FROM bwb_store s LEFT JOIN bwb_collaborator_customer c ON c.customer_id=s.customer_id AND c.user_id=? LEFT JOIN bwb_collaborator_store x ON x.store_id=s.id AND x.user_id=? WHERE c.customer_id IS NOT NULL OR x.store_id IS NOT NULL ORDER BY s.id};
        return if !$DBObject->Prepare( SQL => $SQL, Bind => [ \$Param{UserID}, \$Param{UserID} ] );
    }
    return if $ResponsibleUserID == $Param{UserID} && !$DBObject->Prepare( SQL => $SQL, Bind => [ \$BindID ] );
    my @IDs; while ( my ($ID) = $DBObject->FetchrowArray() ) { push @IDs, $ID }
    return \@IDs;
}

sub CollaboratorAssignmentsSet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{ChangeUserID};
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $DBObject->Do( SQL => 'DELETE FROM bwb_collaborator_customer WHERE user_id = ?', Bind => [ \$Param{UserID} ] ) or return;
    $DBObject->Do( SQL => 'DELETE FROM bwb_collaborator_store WHERE user_id = ?', Bind => [ \$Param{UserID} ] ) or return;
    for my $CustomerID ( @{ $Param{CustomerIDs} || [] } ) {
        $DBObject->Do( SQL => 'INSERT INTO bwb_collaborator_customer (user_id, customer_id, create_time, create_by) VALUES (?, ?, current_timestamp, ?)', Bind => [ \$Param{UserID}, \$CustomerID, \$Param{ChangeUserID} ] ) or return;
    }
    for my $StoreID ( @{ $Param{StoreIDs} || [] } ) {
        $DBObject->Do( SQL => 'INSERT INTO bwb_collaborator_store (user_id, store_id, create_time, create_by) VALUES (?, ?, current_timestamp, ?)', Bind => [ \$Param{UserID}, \$StoreID, \$Param{ChangeUserID} ] ) or return;
    }
    return 1;
}

sub VisualPreferencesCopy {
    my ( $Self, %Param ) = @_;
    return if !$Param{SourceUserID} || !$Param{TargetUserID};

    # Presentation only. Deliberately excludes queue filters, access settings,
    # language, time zone and notifications.
    my @PreferenceKeys = qw(
        UserDashboardPosition
        UserDashboardPref0120-TicketNew-Columns
        UserDashboardPref0120-TicketNew-Shown
        UserDashboardPref0130-TicketOpen-Columns
        UserDashboardPref0130-TicketOpen-Shown
        UserFilterColumnsEnabled-AgentTicketStatusView
        UserStoredFilterColumns-AgentTicketEscalationView
        UserStoredFilterColumns-AgentTicketLockedView
        UserStoredFilterColumns-AgentTicketQueue
        UserStoredFilterColumns-AgentTicketService
        UserStoredFilterColumns-AgentTicketStatusView
        UserTicketOverviewAgentCustomerSearch
        UserTicketOverviewAgentTicketEscalationView
        UserTicketOverviewAgentTicketLockedView
        UserTicketOverviewAgentTicketQueue
        UserTicketOverviewAgentTicketSearch
        UserTicketOverviewAgentTicketService
        UserTicketOverviewAgentTicketStatusView
        UserTicketOverviewSmallPageShown
        UserTicketZoomArticleTableHeight
    );

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    for my $Key (@PreferenceKeys) {
        $DBObject->Do(
            SQL  => 'DELETE FROM user_preferences WHERE user_id = ? AND preferences_key = ?',
            Bind => [ \$Param{TargetUserID}, \$Key ],
        ) or return;
        $DBObject->Do(
            SQL => q{
                INSERT INTO user_preferences (user_id, preferences_key, preferences_value)
                SELECT ?, preferences_key, preferences_value
                FROM user_preferences
                WHERE user_id = ? AND preferences_key = ?
            },
            Bind => [ \$Param{TargetUserID}, \$Param{SourceUserID}, \$Key ],
        ) or return;
    }
    return 1;
}

sub HierarchySet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{ResponsibleUserID} || !$Param{ChangeUserID};
    return if $Param{UserID} == $Param{ResponsibleUserID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $Success = $DBObject->Do(
        SQL => q{
            INSERT INTO bwb_agent_hierarchy
                (user_id, responsible_user_id, create_time, create_by, change_time, change_by)
            VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)
            ON DUPLICATE KEY UPDATE responsible_user_id = VALUES(responsible_user_id),
                change_time = current_timestamp, change_by = VALUES(change_by)
        },
        Bind => [ \$Param{UserID}, \$Param{ResponsibleUserID}, \$Param{ChangeUserID}, \$Param{ChangeUserID} ],
    );
    return if !$Success;

    # A collaborator needs the common agent group and the operational queue
    # groups of the responsible agent. Copying only groups linked to queues
    # deliberately excludes administration and customer-management groups.
    my %OperationalGroupIDs;
    my $UsersGroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
        Group => 'users',
    );
    $OperationalGroupIDs{$UsersGroupID} = 1 if $UsersGroupID;

    if ( $DBObject->Prepare(
        SQL => q{
            SELECT DISTINCT gu.group_id
            FROM group_user gu
            INNER JOIN queue q ON q.group_id = gu.group_id
            WHERE gu.user_id = ? AND gu.permission_key = 'rw'
        },
        Bind => [ \$Param{ResponsibleUserID} ],
    ) ) {
        while ( my ($GroupID) = $DBObject->FetchrowArray() ) {
            $OperationalGroupIDs{$GroupID} = 1;
        }
    }

    my $StatsGroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
        Group => 'stats',
    );
    if ($StatsGroupID) {
        my %ResponsibleStats = $Kernel::OM->Get('Kernel::System::Group')->PermissionUserGet(
            UserID => $Param{ResponsibleUserID},
            Type   => 'rw',
        );
        $OperationalGroupIDs{$StatsGroupID} = 1 if $ResponsibleStats{$StatsGroupID};
    }

    for my $GroupID ( sort { $a <=> $b } keys %OperationalGroupIDs ) {
        $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupUserAdd(
            GID        => $GroupID,
            UID        => $Param{UserID},
            Permission => { rw => 1 },
            UserID     => $Param{ChangeUserID},
        ) or return;
    }

    return 1;
}

sub HierarchyDelete {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM bwb_agent_hierarchy WHERE user_id = ?',
        Bind => [ \$Param{UserID} ],
    );
}

sub CustomersForOwnerSet {
    my ( $Self, %Param ) = @_;
    return if !$Param{OwnerUserID} || !$Param{CustomerIDs} || !$Param{UserID};
    for my $CustomerID ( @{ $Param{CustomerIDs} } ) {
        $Self->CustomerOwnerSet(
            CustomerID => $CustomerID, OwnerUserID => $Param{OwnerUserID}, UserID => $Param{UserID},
        ) or return;
    }
    return 1;
}

1;
