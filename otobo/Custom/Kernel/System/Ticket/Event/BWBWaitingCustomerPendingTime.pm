package Kernel::System::Ticket::Event::BWBWaitingCustomerPendingTime;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBWaitingCustomer
    Kernel::System::Log
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

    my $Waiting = $Kernel::OM->Get('Kernel::System::BWBWaitingCustomer');
    my %OldTicket = %{ $Param{Data}->{OldTicketData} || {} };
    return 1 if $Waiting->IsWaitingCustomerState( $OldTicket{State} );

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return 1 if !%Ticket;
    return 1 if !$Waiting->IsWaitingCustomerState( $Ticket{State} );

    if ( !$Waiting->SetDefaultPendingTill( TicketID => $TicketID, UserID => $UserID ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "BWBWaitingCustomerPendingTime: falha ao gravar Pending till (+"
                . $Waiting->PendingDays()
                . " dias) no ticket $TicketID.",
        );
        return 1;
    }

    return 1;
}

1;
