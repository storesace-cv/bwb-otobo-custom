package Kernel::System::BWBWaitingCustomer;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Ticket
);

use constant WAITING_CUSTOMER_STATE => 'Pendente a aguardar cliente';
use constant PENDING_DAYS           => 3;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub WaitingCustomerState {
    return WAITING_CUSTOMER_STATE;
}

sub IsWaitingCustomerState {
    my ( $Self, $State ) = @_;
    return ( $State || '' ) eq WAITING_CUSTOMER_STATE;
}

sub PendingDays {
    return PENDING_DAYS;
}

sub PendingDiffMinutes {
    return PENDING_DAYS * 24 * 60;
}

sub SetDefaultPendingTill {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Param{TicketID} || 0;
    my $UserID   = $Param{UserID}   || 0;
    if ( !$TicketID || !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'BWBWaitingCustomer::SetDefaultPendingTill precisa de TicketID e UserID.',
        );
        return;
    }

    return $Kernel::OM->Get('Kernel::System::Ticket')->TicketPendingTimeSet(
        Diff     => $Self->PendingDiffMinutes(),
        TicketID => $TicketID,
        UserID   => $UserID,
    );
}

1;
