package Kernel::System::Ticket::Event::BWBTicketCloseCancelAppointments;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBAppointmentCancel
    Kernel::System::Ticket
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if ( $Param{Event} || '' ) ne 'TicketStateUpdate';

    my $TicketID = $Param{Data}->{TicketID} || 0;
    my $UserID   = $Param{UserID}           || 0;
    return 1 if !$TicketID || !$UserID;

    my %OldTicket = %{ $Param{Data}->{OldTicketData} || {} };
    return 1 if ( $OldTicket{StateType} || '' ) =~ /^(?:closed|merged|removed)$/i;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket       = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return 1 if !%Ticket;
    return 1 if ( $Ticket{StateType} || '' ) !~ /^(?:closed|merged|removed)$/i;

    $Kernel::OM->Get('Kernel::System::BWBAppointmentCancel')->CancelFutureForClosedTicket(
        TicketID => $TicketID,
        UserID   => $UserID,
    );

    return 1;
}

1;
