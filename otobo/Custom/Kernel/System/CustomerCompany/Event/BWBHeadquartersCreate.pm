package Kernel::System::CustomerCompany::Event::BWBHeadquartersCreate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBStore',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{Data}->{CustomerID};

    return $Kernel::OM->Get('Kernel::System::BWBStore')->HeadquartersEnsure(
        CustomerID => $Param{Data}->{CustomerID},
        UserID     => $Param{UserID} || 1,
    );
}

1;
