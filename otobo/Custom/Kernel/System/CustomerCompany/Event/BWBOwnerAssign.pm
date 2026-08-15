package Kernel::System::CustomerCompany::Event::BWBOwnerAssign;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{Data}->{CustomerID} || !$Param{UserID};

    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $OwnerUserID = $AccessObject->ResponsibleUserIDGet( UserID => $Param{UserID} );

    # A global administrator may create a customer before explicitly assigning
    # it.  Use the creating administrator as a safe temporary owner.
    $OwnerUserID ||= $Param{UserID};

    return $AccessObject->CustomerOwnerSet(
        CustomerID  => $Param{Data}->{CustomerID},
        OwnerUserID => $OwnerUserID,
        UserID      => $Param{UserID},
    );
}

1;
