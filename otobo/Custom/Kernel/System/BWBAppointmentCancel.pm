package Kernel::System::BWBAppointmentCancel;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBAppointmentCheck
    Kernel::System::Calendar::Appointment
    Kernel::System::Log
    Kernel::System::Ticket
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub CancelFutureForClosedTicket {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Param{TicketID} || 0;
    my $UserID   = $Param{UserID}   || 0;
    return if !$TicketID || !$UserID;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket       = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;

    my $CheckObject  = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    my $ApptObject   = $Kernel::OM->Get('Kernel::System::Calendar::Appointment');
    my $Prefix       = $CheckObject->CancelledTitlePrefix();
    my $NowObject    = $Kernel::OM->Create('Kernel::System::DateTime');
    my $ReasonStamp  = $NowObject ? $NowObject->Format( Format => '%d/%m/%Y %H:%M' ) : '';
    my $Reason       = sprintf(
        'Cancelada automaticamente: o ticket #%s foi encerrado (%s) em %s antes da data agendada.',
        $Ticket{TicketNumber} || $TicketID,
        $Ticket{State}        || 'encerrado',
        $ReasonStamp,
    );

    my @Appointments = $CheckObject->FutureAppointmentsForTicket( TicketID => $TicketID );
    return 1 if !@Appointments;

    $CheckObject->{SkipSync} = 1;

    APPOINTMENT:
    for my $Row (@Appointments) {
        next APPOINTMENT if $Row->{Recurring} || $Row->{ParentID};
        next APPOINTMENT if $CheckObject->IsCancelledTitle( $Row->{Title} );

        my %Appointment = $ApptObject->AppointmentGet(
            AppointmentID => $Row->{AppointmentID},
        );
        next APPOINTMENT if !%Appointment;

        my $Title = $Appointment{Title} || '';
        if ( !$CheckObject->IsCancelledTitle($Title) ) {
            $Title = $Prefix . $Title;
        }

        my $Description = $Appointment{Description} || '';
        if ( $Description !~ /\Q$Reason\E/s ) {
            $Description .= "\n\n---\n" . $ReasonStamp . "\n" . $Reason;
        }

        my $Success = $ApptObject->AppointmentUpdate(
            AppointmentID                         => $Appointment{AppointmentID},
            CalendarID                            => $Appointment{CalendarID},
            Title                                 => $Title,
            Description                           => $Description,
            Location                              => $Appointment{Location} || '',
            StartTime                             => $Appointment{StartTime},
            EndTime                               => $Appointment{EndTime},
            AllDay                                => $Appointment{AllDay} || 0,
            TeamID                                => $Appointment{TeamID} || [],
            ResourceID                            => $Appointment{ResourceID} || [0],
            Recurring                             => 0,
            NotificationDate                      => '',
            NotificationTemplate                  => '',
            NotificationCustom                    => '',
            NotificationCustomRelativeUnitCount   => 0,
            NotificationCustomRelativeUnit        => '',
            NotificationCustomRelativePointOfTime => '',
            NotificationCustomDateTime            => '',
            UserID                                => $UserID,
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "BWBAppointmentCancel: não foi possível cancelar a marcação $Row->{AppointmentID} do ticket $TicketID.",
            );
        }
    }

    $CheckObject->{SkipSync} = 0;
    return 1;
}

1;
