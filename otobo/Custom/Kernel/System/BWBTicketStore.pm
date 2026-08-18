package Kernel::System::BWBTicketStore;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBStore',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Get {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL => q{
            SELECT ts.ticket_id, ts.store_id, s.customer_id, s.store_number, s.name, s.street
            FROM bwb_ticket_store ts
            INNER JOIN bwb_store s ON s.id = ts.store_id
            WHERE ts.ticket_id = ?
        },
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );
    my @Row = $DBObject->FetchrowArray();
    return if !@Row;

    return {
        TicketID    => $Row[0],
        StoreID     => $Row[1],
        CustomerID  => $Row[2],
        StoreNumber => $Row[3],
        StoreName   => $Row[4],
        StoreStreet => $Row[5] // '',
        Label       => $Self->_Label( $Row[3], $Row[4] ),
    };
}

sub LabelGet {
    my ( $Self, %Param ) = @_;
    my $Data = $Self->Get(%Param) || {};
    return $Data->{Label} || '';
}

sub AddressGet {
    my ( $Self, %Param ) = @_;
    my $Data = $Self->Get(%Param) || {};
    return $Data->{StoreStreet} || '';
}

sub Set {
    my ( $Self, %Param ) = @_;
    for my $Needed (qw(TicketID StoreID UserID)) {
        return if !$Param{$Needed};
    }

    my %Store = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreGet(
        StoreID => $Param{StoreID},
    );
    return if !%Store;

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;
    if ( $Ticket{CustomerID} && $Store{CustomerID} ne $Ticket{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "BWBTicketStore: loja $Param{StoreID} não pertence ao cliente do ticket $Param{TicketID}.",
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Do(
        SQL => q{
            INSERT INTO bwb_ticket_store
                (ticket_id, store_id, create_time, create_by, change_time, change_by)
            VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)
            ON DUPLICATE KEY UPDATE
                store_id = ?,
                change_time = current_timestamp,
                change_by = ?
        },
        Bind => [
            \$Param{TicketID}, \$Param{StoreID}, \$Param{UserID}, \$Param{UserID},
            \$Param{StoreID}, \$Param{UserID},
        ],
    );

    my $Label = $Self->_Label( $Store{StoreNumber}, $Store{StoreName} );
    $Self->_MirrorDynamicField(
        TicketID => $Param{TicketID},
        Label    => $Label,
        UserID   => $Param{UserID},
    );

    if ( $Param{History} ) {
        $Kernel::OM->Get('Kernel::System::Ticket')->HistoryAdd(
            TicketID     => $Param{TicketID},
            HistoryType  => 'Misc',
            Name         => "Loja alterada para $Label",
            CreateUserID => $Param{UserID},
        );
    }

    return $Param{StoreID};
}

sub EnsureFromCustomerUser {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID};
    my $UserID = $Param{UserID} || 1;

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return 1 if !%Ticket;

    my $Existing = $Self->Get( TicketID => $Param{TicketID} );
    if (
        $Param{OnlyIfEmpty}
        && $Existing
        && ( !$Ticket{CustomerID} || $Existing->{CustomerID} eq $Ticket{CustomerID} )
        )
    {
        return $Existing->{StoreID};
    }

    my $StoreID;
    if ( $Ticket{CustomerUserID} ) {
        my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
        my $UserStoreID = $CustomerUser{UserStoreID} || 0;
        if ($UserStoreID) {
            my %Store = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreGet(
                StoreID => $UserStoreID,
            );
            if (
                %Store
                && ( !$Ticket{CustomerID} || $Store{CustomerID} eq $Ticket{CustomerID} )
                )
            {
                $StoreID = $UserStoreID;
            }
        }
    }

    if ( !$StoreID && $Ticket{CustomerID} ) {
        $StoreID = $Kernel::OM->Get('Kernel::System::BWBStore')->HeadquartersEnsure(
            CustomerID => $Ticket{CustomerID},
            UserID     => $UserID,
        );
    }

    return 1 if !$StoreID;
    return $Self->Set(
        TicketID => $Param{TicketID},
        StoreID  => $StoreID,
        UserID   => $UserID,
    );
}

sub StoresForTicket {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{TicketID} || !$Param{UserID};

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return [] if !%Ticket || !$Ticket{CustomerID};

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Stores = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreList(
        CustomerID => $Ticket{CustomerID},
    ) || [];

    my @Allowed;
    for my $Store ( @{$Stores} ) {
        next if !$Access->StoreAccessCheck(
            UserID  => $Param{UserID},
            StoreID => $Store->{StoreID},
        );
        push @Allowed, {
            %{$Store},
            Label => $Self->_Label( $Store->{StoreNumber}, $Store->{StoreName} ),
        };
    }
    return \@Allowed;
}

sub _Label {
    my ( $Self, $Number, $Name ) = @_;
    return join ' | ', grep { defined && length } ( $Number, $Name );
}

sub _MirrorDynamicField {
    my ( $Self, %Param ) = @_;
    my $FieldConfig = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        Name => 'BWBStore',
    );
    return 1 if !$FieldConfig || !$FieldConfig->{ID};

    return $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $FieldConfig,
        ObjectID           => $Param{TicketID},
        Value              => $Param{Label} // '',
        UserID             => $Param{UserID},
    );
}

1;
