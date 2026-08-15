package Kernel::System::Ticket::Permission::BWBCustomerOwnerCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID} || !$Param{UserID};

    return $Kernel::OM->Get('Kernel::System::BWBAccess')->TicketAccessCheck(
        UserID => $Param{UserID}, TicketID => $Param{TicketID},
    );
}

1;
