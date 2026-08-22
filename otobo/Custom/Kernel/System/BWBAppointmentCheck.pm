package Kernel::System::BWBAppointmentCheck;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::DB
    Kernel::System::Log
);

use constant PENDING_SCHEDULED_STATE => 'Pendente até determinada data';
use constant CANCELLED_TITLE_PREFIX  => '[CANCELADO] ';

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub CancelledTitlePrefix {
    return CANCELLED_TITLE_PREFIX;
}

sub IsCancelledTitle {
    my ( $Self, $Title ) = @_;
    return index( $Title || '', CANCELLED_TITLE_PREFIX ) == 0 ? 1 : 0;
}

sub PendingScheduledState {
    return PENDING_SCHEDULED_STATE;
}

sub StateRequiresAppointment {
    my ( $Self, $State ) = @_;
    return ( $State || '' ) eq PENDING_SCHEDULED_STATE;
}

sub _FutureAppointmentSQLExtra {
    return q{
        AND ca.title NOT LIKE '[CANCELADO]%'
    };
}

sub FutureAppointmentsForTicket {
    my ( $Self, %Param ) = @_;
    my $TicketID = $Param{TicketID} || return;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL => q{
            SELECT ca.id, ca.calendar_id, ca.title, ca.description, ca.start_time, ca.end_time,
                   ca.all_day, ca.recurring, ca.parent_id
            FROM calendar_appointment ca
            INNER JOIN link_relation lr ON lr.source_key = ca.id
            INNER JOIN link_object lo_src ON lo_src.id = lr.source_object_id AND lo_src.name = 'Appointment'
            INNER JOIN link_object lo_tgt ON lo_tgt.id = lr.target_object_id AND lo_tgt.name = 'Ticket'
            INNER JOIN link_state ls ON ls.id = lr.state_id AND ls.name = 'Valid'
            WHERE lr.target_key = ?
              AND ca.start_time > UTC_TIMESTAMP()
        } . $Self->_FutureAppointmentSQLExtra() . q{
            ORDER BY ca.start_time ASC
        },
        Bind => [ \$TicketID ],
    );

    my @Rows;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Rows, {
            AppointmentID => $Data[0],
            CalendarID    => $Data[1],
            Title         => $Data[2],
            Description   => $Data[3],
            StartTime     => $Data[4],
            EndTime       => $Data[5],
            AllDay        => $Data[6],
            Recurring     => $Data[7],
            ParentID      => $Data[8],
        };
    }
    return @Rows;
}

sub HasFutureAppointment {
    my ( $Self, %Param ) = @_;
    return $Self->NextFutureStart(%Param) ? 1 : 0;
}

sub NextFutureStart {
    my ( $Self, %Param ) = @_;
    my $TicketID = $Param{TicketID} || return;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL => q{
            SELECT ca.start_time
            FROM calendar_appointment ca
            INNER JOIN link_relation lr ON lr.source_key = ca.id
            INNER JOIN link_object lo_src ON lo_src.id = lr.source_object_id AND lo_src.name = 'Appointment'
            INNER JOIN link_object lo_tgt ON lo_tgt.id = lr.target_object_id AND lo_tgt.name = 'Ticket'
            INNER JOIN link_state ls ON ls.id = lr.state_id AND ls.name = 'Valid'
            WHERE lr.target_key = ?
              AND ca.start_time > UTC_TIMESTAMP()
        } . $Self->_FutureAppointmentSQLExtra() . q{
            ORDER BY ca.start_time ASC
            LIMIT 1
        },
        Bind => [ \$TicketID ],
    );
    my ($Start) = $DBObject->FetchrowArray();
    return $Start;
}

sub LinkedTicketIDs {
    my ( $Self, %Param ) = @_;
    my $AppointmentID = $Param{AppointmentID} || return;
    my $DBObject      = $Kernel::OM->Get('Kernel::System::DB');
    my %TicketIDs;

    if (
        $DBObject->Prepare(
            SQL => q{
                SELECT lr.target_key
                FROM link_relation lr
                INNER JOIN link_object lo_src ON lo_src.id = lr.source_object_id AND lo_src.name = 'Appointment'
                INNER JOIN link_object lo_tgt ON lo_tgt.id = lr.target_object_id AND lo_tgt.name = 'Ticket'
                INNER JOIN link_state ls ON ls.id = lr.state_id AND ls.name = 'Valid'
                WHERE lr.source_key = ?
            },
            Bind => [ \$AppointmentID ],
        )
        )
    {
        while ( my ($TicketID) = $DBObject->FetchrowArray() ) {
            next if !$TicketID;
            $TicketIDs{$TicketID} = 1;
        }
    }

    if (
        $DBObject->Prepare(
            SQL  => 'SELECT ticket_id FROM calendar_appointment_ticket WHERE appointment_id = ?',
            Bind => [ \$AppointmentID ],
        )
        )
    {
        while ( my ($TicketID) = $DBObject->FetchrowArray() ) {
            next if !$TicketID;
            $TicketIDs{$TicketID} = 1;
        }
    }

    return sort { $a <=> $b } keys %TicketIDs;
}

sub GuardIsSkipped {
    my ($Self) = @_;
    return $Self->{SkipGuard} ? 1 : 0;
}

sub GuardSkipSet {
    my ( $Self, $Value ) = @_;
    $Self->{SkipGuard} = $Value ? 1 : 0;
    return 1;
}

1;
