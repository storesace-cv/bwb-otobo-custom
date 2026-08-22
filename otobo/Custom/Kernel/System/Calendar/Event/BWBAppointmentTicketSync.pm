package Kernel::System::Calendar::Event::BWBAppointmentTicketSync;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBAccess
    Kernel::System::BWBAppointmentCheck
    Kernel::System::Calendar::Appointment
    Kernel::System::Log
    Kernel::System::Ticket
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Event Data UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "BWBAppointmentTicketSync: Need $Needed!",
            );
            return;
        }
    }

    my $AppointmentID = $Param{Data}->{AppointmentID} || 0;
    return 1 if !$AppointmentID;

    my $CheckObject = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    return 1 if $CheckObject->{SkipSync};

    my @TicketIDs = $CheckObject->LinkedTicketIDs( AppointmentID => $AppointmentID );
    return 1 if !@TicketIDs;

    if ( ( $Param{Event} || '' ) eq 'AppointmentDelete' ) {
        for my $TicketID (@TicketIDs) {
            $Self->_HandleDelete(
                TicketID => $TicketID,
                UserID   => $Param{UserID},
            );
        }
        return 1;
    }

    my %Appointment = $Kernel::OM->Get('Kernel::System::Calendar::Appointment')->AppointmentGet(
        AppointmentID => $AppointmentID,
        UserID        => $Param{UserID},
    );
    return 1 if !%Appointment;
    return 1 if $CheckObject->IsCancelledTitle( $Appointment{Title} );

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 1 if !$DBObject->Prepare(
        SQL  => 'SELECT 1 FROM calendar_appointment WHERE id = ? AND start_time > UTC_TIMESTAMP() LIMIT 1',
        Bind => [ \$AppointmentID ],
    );
    my ($IsFuture) = $DBObject->FetchrowArray();
    return 1 if !$IsFuture;

    for my $TicketID (@TicketIDs) {
        $Self->_SyncTicket(
            TicketID  => $TicketID,
            StartTime => $Appointment{StartTime},
            UserID    => $Param{UserID},
        );
    }

    return 1;
}

sub _SyncTicket {
    my ( $Self, %Param ) = @_;

    my $TicketID  = $Param{TicketID}  || return;
    my $StartTime = $Param{StartTime} || return;
    my $UserID    = $Param{UserID}    || return;

    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    return if !$AccessObject->TicketAccessCheck( UserID => $UserID, TicketID => $TicketID );

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket       = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;
    return if $Ticket{StateType} =~ /^(?:closed|merged|removed)$/i;

    my $TargetState = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck')->PendingScheduledState();

    if ( $Ticket{State} ne $TargetState ) {
        my $Success = $TicketObject->TicketStateSet(
            TicketID => $TicketID,
            State    => $TargetState,
            UserID   => $UserID,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "BWBAppointmentTicketSync: não foi possível aplicar estado ao ticket $TicketID.",
            );
            return;
        }
    }

    if ( !$TicketObject->TicketPendingTimeSet(
            TicketID => $TicketID,
            String   => $StartTime,
            UserID   => $UserID,
        )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "BWBAppointmentTicketSync: não foi possível gravar Pending till no ticket $TicketID.",
        );
    }

    return 1;
}

sub _HandleDelete {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Param{TicketID} || return;
    my $UserID   = $Param{UserID}   || return;

    my $CheckObject = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    return if $CheckObject->HasFutureAppointment( TicketID => $TicketID );

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket       = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;
    return if ( $Ticket{State} || '' ) ne $CheckObject->PendingScheduledState();

    $TicketObject->TicketPendingTimeSet(
        TicketID => $TicketID,
        String   => '',
        UserID   => $UserID,
    );

    return 1;
}

1;
