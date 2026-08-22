package Kernel::System::Ticket::Event::BWBStateRequiresAppointment;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBAppointmentCheck
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

    my $CheckObject = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    return 1 if $CheckObject->GuardIsSkipped();

    my %OldTicket = %{ $Param{Data}->{OldTicketData} || {} };
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket       = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return 1 if !%Ticket;
    return 1 if !$CheckObject->StateRequiresAppointment( $Ticket{State} );
    return 1 if $CheckObject->HasFutureAppointment( TicketID => $TicketID );

    my $OldState = $OldTicket{State} || 'open';
    $CheckObject->GuardSkipSet(1);
    my $Success = $TicketObject->TicketStateSet(
        TicketID => $TicketID,
        State    => $OldState,
        UserID   => $UserID,
    );
    $CheckObject->GuardSkipSet(0);

    if ( !$Success ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "BWBStateRequiresAppointment: não foi possível reverter o ticket $TicketID.",
        );
        return 1;
    }

    $TicketObject->HistoryAdd(
        TicketID     => $TicketID,
        HistoryType  => 'Misc',
        Name         => 'Estado «Pendente com Agendamento» exige uma marcação futura no calendário com este ticket.',
        CreateUserID => $UserID,
    );

    return 1;
}

1;
