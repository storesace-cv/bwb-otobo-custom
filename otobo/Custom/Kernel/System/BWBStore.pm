package Kernel::System::BWBStore;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CustomerCompany',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = bless {}, $Type;
    return $Self;
}

sub _NormalizeCoord {
    my ( $Self, $Value, $Min, $Max ) = @_;
    return undef if !defined $Value || $Value eq '';
    $Value =~ s/^\s+|\s+$//g;
    $Value =~ s/,/./g;
    return undef if $Value !~ /^-?\d+(?:\.\d+)?$/;
    my $Num = 0 + $Value;
    return undef if $Num < $Min || $Num > $Max;
    return sprintf( '%.7f', $Num );
}

sub StoreGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{StoreID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL => q{
            SELECT s.id, s.customer_id, c.name, s.store_number, s.name,
                   s.street, s.latitude, s.longitude, s.valid_id,
                   s.create_time, s.change_time
            FROM bwb_store s
            INNER JOIN customer_company c ON c.customer_id = s.customer_id
            WHERE s.id = ?
        },
        Bind => [ \$Param{StoreID} ],
    );

    my @Row = $DBObject->FetchrowArray();
    return if !@Row;

    return (
        StoreID             => $Row[0],
        CustomerID          => $Row[1],
        CustomerCompanyName => $Row[2],
        StoreNumber         => $Row[3],
        StoreName           => $Row[4],
        StoreStreet         => $Row[5],
        Latitude            => $Row[6],
        Longitude           => $Row[7],
        ValidID             => $Row[8],
        CreateTime          => $Row[9],
        ChangeTime          => $Row[10],
    );
}

sub StoreList {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my @Bind;
    my $Where = '1=1';

    if ( !$Param{IncludeInvalid} ) {
        $Where .= ' AND s.valid_id = 1 AND c.valid_id = 1';
    }
    if ( $Param{CustomerID} ) {
        $Where .= ' AND s.customer_id = ?';
        push @Bind, \$Param{CustomerID};
    }
    if ( defined $Param{Search} && length $Param{Search} ) {
        my $Search = $Param{Search};
        $Search =~ s/\*/%/g;
        $Search = "%$Search%" if $Search !~ /%/;
        $Where .= q{ AND (c.name LIKE ? OR s.store_number LIKE ? OR s.name LIKE ? OR s.street LIKE ?)};
        push @Bind, \$Search, \$Search, \$Search, \$Search;
    }

    return if !$DBObject->Prepare(
        SQL => qq{
            SELECT s.id, s.customer_id, c.name, s.store_number, s.name,
                   s.street, s.latitude, s.longitude, s.valid_id,
                   s.create_time, s.change_time
            FROM bwb_store s
            INNER JOIN customer_company c ON c.customer_id = s.customer_id
            WHERE $Where
            ORDER BY c.name, CASE WHEN s.store_number = 'S' THEN 0 ELSE 1 END,
                     CAST(s.store_number AS UNSIGNED), s.store_number, s.name
        },
        Bind => \@Bind,
    );

    my @Stores;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Stores, {
            StoreID             => $Row[0],
            CustomerID          => $Row[1],
            CustomerCompanyName => $Row[2],
            StoreNumber         => $Row[3],
            StoreName           => $Row[4],
            StoreStreet         => $Row[5],
            Latitude            => $Row[6],
            Longitude           => $Row[7],
            ValidID             => $Row[8],
            CreateTime          => $Row[9],
            ChangeTime          => $Row[10],
        };
    }
    return \@Stores;
}

sub StoreAdd {
    my ( $Self, %Param ) = @_;
    for my $Needed (qw(CustomerID StoreNumber StoreName ValidID UserID)) {
        return if !defined $Param{$Needed} || $Param{$Needed} eq '';
    }

    my $Lat = $Self->_NormalizeCoord( $Param{Latitude},  -90,  90 );
    my $Lon = $Self->_NormalizeCoord( $Param{Longitude}, -180, 180 );
    if ( ( defined $Param{Latitude} && $Param{Latitude} ne '' && !defined $Lat )
        || ( defined $Param{Longitude} && $Param{Longitude} ne '' && !defined $Lon ) )
    {
        return;
    }
    if ( ( defined $Lat && !defined $Lon ) || ( !defined $Lat && defined $Lon ) ) {
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Do(
        SQL => q{
            INSERT INTO bwb_store
                (customer_id, store_number, name, street, latitude, longitude, valid_id,
                 create_time, create_by, change_time, change_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)
        },
        Bind => [
            \$Param{CustomerID}, \$Param{StoreNumber}, \$Param{StoreName},
            \$Param{StoreStreet}, \$Lat, \$Lon, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID},
        ],
    );
    return if !$DBObject->Prepare( SQL => 'SELECT LAST_INSERT_ID()' );
    my ($StoreID) = $DBObject->FetchrowArray();
    return $StoreID;
}

sub StoreUpdate {
    my ( $Self, %Param ) = @_;
    for my $Needed (qw(StoreID CustomerID StoreNumber StoreName ValidID UserID)) {
        return if !defined $Param{$Needed} || $Param{$Needed} eq '';
    }

    my $Lat = $Self->_NormalizeCoord( $Param{Latitude},  -90,  90 );
    my $Lon = $Self->_NormalizeCoord( $Param{Longitude}, -180, 180 );
    if ( ( defined $Param{Latitude} && $Param{Latitude} ne '' && !defined $Lat )
        || ( defined $Param{Longitude} && $Param{Longitude} ne '' && !defined $Lon ) )
    {
        return;
    }
    if ( ( defined $Lat && !defined $Lon ) || ( !defined $Lat && defined $Lon ) ) {
        return;
    }

    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            UPDATE bwb_store
            SET customer_id = ?, store_number = ?, name = ?, street = ?,
                latitude = ?, longitude = ?,
                valid_id = ?, change_time = current_timestamp, change_by = ?
            WHERE id = ?
        },
        Bind => [
            \$Param{CustomerID}, \$Param{StoreNumber}, \$Param{StoreName},
            \$Param{StoreStreet}, \$Lat, \$Lon, \$Param{ValidID},
            \$Param{UserID}, \$Param{StoreID},
        ],
    );
}

sub HeadquartersEnsure {
    my ( $Self, %Param ) = @_;
    return if !$Param{CustomerID} || !$Param{UserID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => q{SELECT id FROM bwb_store WHERE customer_id = ? AND store_number = 'S' LIMIT 1},
        Bind => [ \$Param{CustomerID} ],
    );
    my ($StoreID) = $DBObject->FetchrowArray();
    return $StoreID if $StoreID;

    my %Company = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
        CustomerID => $Param{CustomerID},
    );
    return if !%Company;

    return $Self->StoreAdd(
        CustomerID   => $Param{CustomerID},
        StoreNumber  => 'S',
        StoreName    => 'Sede',
        StoreStreet  => $Company{CustomerCompanyStreet} || '',
        ValidID      => 1,
        UserID       => $Param{UserID},
    );
}

sub HeadquartersEnsureAll {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};

    my %Companies = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
        Valid => 0,
    );
    for my $CustomerID ( sort keys %Companies ) {
        $Self->HeadquartersEnsure(
            CustomerID => $CustomerID,
            UserID     => $Param{UserID},
        );
    }
    return 1;
}

1;
