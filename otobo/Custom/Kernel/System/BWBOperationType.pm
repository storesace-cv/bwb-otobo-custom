package Kernel::System::BWBOperationType;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::DB',
);

sub new { my ($Type) = @_; return bless {}, $Type; }

sub OwnerUserIDGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    return $Kernel::OM->Get('Kernel::System::BWBAccess')->ResponsibleUserIDGet( UserID => $Param{UserID} );
}

sub List {
    my ( $Self, %Param ) = @_;
    my $OwnerUserID = $Self->OwnerUserIDGet( UserID => $Param{UserID} ) || return [];
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL => q{
            SELECT t.id, t.name, t.is_global, t.owner_user_id, t.valid_id,
                   CASE WHEN h.operation_type_id IS NULL THEN 0 ELSE 1 END AS hidden
            FROM bwb_operation_type t
            LEFT JOIN bwb_operation_type_hidden h
              ON h.operation_type_id = t.id AND h.owner_user_id = ?
            WHERE t.is_global = 1 OR t.owner_user_id = ?
            ORDER BY t.sort_order, t.name
        },
        Bind => [ \$OwnerUserID, \$OwnerUserID ],
    );
    my @Items;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Items, { ID => $Row[0], Name => $Row[1], IsGlobal => $Row[2], OwnerUserID => $Row[3], ValidID => $Row[4], Hidden => $Row[5] };
    }
    return \@Items;
}

sub AvailableList {
    my ( $Self, %Param ) = @_;
    return [ grep { $_->{ValidID} == 1 && !$_->{Hidden} } @{ $Self->List(%Param) } ];
}

sub Add {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{Name};
    my $OwnerUserID = $Self->OwnerUserIDGet( UserID => $Param{UserID} ) || return;
    $Param{Name} =~ s/^\s+|\s+$//g;
    return if !$Param{Name};
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{INSERT INTO bwb_operation_type (name,is_global,owner_user_id,sort_order,valid_id,create_time,create_by,change_time,change_by) VALUES (?,0,?,999,1,current_timestamp,?,current_timestamp,?)},
        Bind => [ \$Param{Name}, \$OwnerUserID, \$Param{UserID}, \$Param{UserID} ],
    );
}

sub OwnUpdate {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{ID} || !$Param{Name};
    my $OwnerUserID = $Self->OwnerUserIDGet( UserID => $Param{UserID} ) || return;
    $Param{Name} =~ s/^\s+|\s+$//g;
    return if !$Param{Name};
    my $ValidID = $Param{ValidID} == 1 ? 1 : 2;
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE bwb_operation_type SET name=?,valid_id=?,change_time=current_timestamp,change_by=? WHERE id=? AND is_global=0 AND owner_user_id=?',
        Bind => [ \$Param{Name}, \$ValidID, \$Param{UserID}, \$Param{ID}, \$OwnerUserID ],
    );
}

sub GlobalHiddenSet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{ID};
    my $OwnerUserID = $Self->OwnerUserIDGet( UserID => $Param{UserID} ) || return;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $DBObject->Do( SQL => 'DELETE FROM bwb_operation_type_hidden WHERE owner_user_id=? AND operation_type_id=?', Bind => [ \$OwnerUserID, \$Param{ID} ] ) or return;
    return 1 if !$Param{Hidden};
    return $DBObject->Do(
        SQL => q{INSERT INTO bwb_operation_type_hidden (owner_user_id,operation_type_id,create_time,create_by) SELECT ?,id,current_timestamp,? FROM bwb_operation_type WHERE id=? AND is_global=1},
        Bind => [ \$OwnerUserID, \$Param{UserID}, \$Param{ID} ],
    );
}

sub NameAllowed {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{Name};
    for my $Item ( @{ $Self->AvailableList( UserID => $Param{UserID} ) } ) {
        return $Item->{Name} if $Item->{Name} eq $Param{Name};
    }
    return;
}

1;
