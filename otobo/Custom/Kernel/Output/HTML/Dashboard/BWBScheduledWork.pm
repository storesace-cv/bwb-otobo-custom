package Kernel::Output::HTML::Dashboard::BWBScheduledWork;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {%Param};
    bless $Self, $Type;

    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if !$Self->{$Needed};
    }

    return $Self;
}

sub Preferences { return; }

sub Config {
    my ($Self) = @_;
    return ( %{ $Self->{Config} }, CacheKey => undef, CacheTTL => undef );
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return if !$DBObject->Prepare(
        SQL => q{
            SELECT ca.id, ca.start_time, ca.end_time, ca.title,
                   lr.target_key AS ticket_id
            FROM calendar_appointment ca
            INNER JOIN link_relation lr ON lr.source_key = ca.id
            INNER JOIN link_object lo_src ON lo_src.id = lr.source_object_id AND lo_src.name = 'Appointment'
            INNER JOIN link_object lo_tgt ON lo_tgt.id = lr.target_object_id AND lo_tgt.name = 'Ticket'
            INNER JOIN link_state ls ON ls.id = lr.state_id AND ls.name = 'Valid'
            INNER JOIN ticket t ON t.id = lr.target_key
            INNER JOIN ticket_state ts ON ts.id = t.ticket_state_id
            INNER JOIN ticket_state_type tst ON tst.id = ts.type_id
            WHERE ca.start_time > UTC_TIMESTAMP()
              AND tst.id NOT IN (3, 6, 7)
            ORDER BY ca.start_time ASC
            LIMIT 200
        },
    );

    my @Raw;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Raw, [@Data];
    }

    my @Rows;
    for my $Data (@Raw) {
        my ( $AppointmentID, $StartUTC, $EndUTC, $ApptTitle, $TicketID ) = @{$Data};
        next if !$AccessObject->TicketAccessCheck( UserID => $Self->{UserID}, TicketID => $TicketID );

        my %Ticket = $TicketObject->TicketGet( TicketID => $TicketID, DynamicFields => 0, Silent => 1 );
        next if !%Ticket;

        my $Start = $StartUTC;
        my $StartObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { String => $StartUTC, TimeZone => 'UTC' },
        );
        if ($StartObject) {
            my %Viewer = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Self->{UserID} );
            $StartObject->ToTimeZone( TimeZone => $Viewer{UserTimeZone} || 'Europe/Lisbon' );
            $Start = $StartObject->Format( Format => '%d/%m/%Y %H:%M' );
        }

        push @Rows, {
            AppointmentID => $AppointmentID,
            TicketID      => $TicketID,
            TicketNumber  => $Ticket{TicketNumber},
            Title         => $Ticket{Title},
            Appointment   => $ApptTitle || $Ticket{Title},
            Customer      => $Ticket{CustomerCompanyName} || $Ticket{CustomerName} || $Ticket{CustomerID} || '-',
            Store         => $Kernel::OM->Get('Kernel::System::BWBTicketStore')->LabelGet(
                TicketID => $TicketID,
            ) || '-',
            Start         => $Start,
        };
    }

    for my $Row (@Rows) {
        $LayoutObject->Block( Name => 'BWBScheduledWorkRow', Data => $Row );
    }
    if ( !@Rows ) {
        $LayoutObject->Block( Name => 'BWBScheduledWorkNone' );
    }

    return $LayoutObject->Output(
        TemplateFile => 'AgentDashboardBWBScheduledWork',
        Data         => { Count => scalar @Rows },
    );
}

1;
