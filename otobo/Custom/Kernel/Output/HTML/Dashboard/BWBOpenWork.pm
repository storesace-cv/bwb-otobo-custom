package Kernel::Output::HTML::Dashboard::BWBOpenWork;

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

    $Self->{PrefKey} = 'UserDashboardPref' . $Self->{Name} . '-Shown';
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
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $ResponsibleUserID = $AccessObject->ResponsibleUserIDGet( UserID => $Self->{UserID} ) || $Self->{UserID};
    my ( $SQL, @BindValues );

    if ( $AccessObject->IsGlobalAdministrator( UserID => $Self->{UserID} ) ) {
        $SQL = q{
            SELECT s.id, s.ticket_id, s.user_id, s.work_type, s.start_time,
                   w.paused_at, COALESCE(w.paused_seconds, 0),
                   GREATEST(0, TIMESTAMPDIFF(SECOND, s.start_time, UTC_TIMESTAMP())
                     - COALESCE(w.paused_seconds, 0)
                     - CASE WHEN w.paused_at IS NULL THEN 0
                            ELSE TIMESTAMPDIFF(SECOND, w.paused_at, UTC_TIMESTAMP()) END)
            FROM bwb_work_session s
            LEFT JOIN bwb_work_sheet w ON w.session_id = s.id
            WHERE s.end_time IS NULL
            ORDER BY s.start_time DESC
        };
    }
    elsif ( $ResponsibleUserID == $Self->{UserID} ) {
        $SQL = q{
            SELECT s.id, s.ticket_id, s.user_id, s.work_type, s.start_time,
                   w.paused_at, COALESCE(w.paused_seconds, 0),
                   GREATEST(0, TIMESTAMPDIFF(SECOND, s.start_time, UTC_TIMESTAMP())
                     - COALESCE(w.paused_seconds, 0)
                     - CASE WHEN w.paused_at IS NULL THEN 0
                            ELSE TIMESTAMPDIFF(SECOND, w.paused_at, UTC_TIMESTAMP()) END)
            FROM bwb_work_session s
            LEFT JOIN bwb_work_sheet w ON w.session_id = s.id
            LEFT JOIN bwb_agent_hierarchy h ON h.user_id = s.user_id
            WHERE s.end_time IS NULL
              AND (s.user_id = ? OR h.responsible_user_id = ?)
            ORDER BY s.start_time DESC
        };
        @BindValues = ( $Self->{UserID}, $Self->{UserID} );
    }
    else {
        $SQL = q{
            SELECT s.id, s.ticket_id, s.user_id, s.work_type, s.start_time,
                   w.paused_at, COALESCE(w.paused_seconds, 0),
                   GREATEST(0, TIMESTAMPDIFF(SECOND, s.start_time, UTC_TIMESTAMP())
                     - COALESCE(w.paused_seconds, 0)
                     - CASE WHEN w.paused_at IS NULL THEN 0
                            ELSE TIMESTAMPDIFF(SECOND, w.paused_at, UTC_TIMESTAMP()) END)
            FROM bwb_work_session s
            LEFT JOIN bwb_work_sheet w ON w.session_id = s.id
            WHERE s.end_time IS NULL AND s.user_id = ?
            ORDER BY s.start_time DESC
        };
        @BindValues = ($Self->{UserID});
    }

    my @Bind = map { \$BindValues[$_] } 0 .. $#BindValues;
    my %Prepare = ( SQL => $SQL );
    $Prepare{Bind} = \@Bind if @Bind;
    return if !$DBObject->Prepare(%Prepare);

    # Drain the cursor before TicketAccessCheck/TicketGet — those reuse the
    # same DB handle and would otherwise hide every session after the first.
    my @Raw;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Raw, [@Data];
    }

    my @Rows;
    for my $Data (@Raw) {
        my ( $SessionID, $TicketID, $TechnicianID, $WorkType, $StartUTC, $PausedAt, $PausedSeconds, $ActiveSeconds ) = @{$Data};
        next if !$AccessObject->TicketAccessCheck( UserID => $Self->{UserID}, TicketID => $TicketID );

        my %Ticket = $TicketObject->TicketGet( TicketID => $TicketID, DynamicFields => 0, Silent => 1 );
        next if !%Ticket;
        my %Technician = $UserObject->GetUserData( UserID => $TechnicianID );

        my $Start = $StartUTC;
        my $StartObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { String => $StartUTC, TimeZone => 'UTC' },
        );
        if ($StartObject) {
            my %Viewer = $UserObject->GetUserData( UserID => $Self->{UserID} );
            $StartObject->ToTimeZone( TimeZone => $Viewer{UserTimeZone} || 'Europe/Lisbon' );
            $Start = $StartObject->Format( Format => '%d/%m/%Y %H:%M' );
        }

        my $Minutes = int( ( $ActiveSeconds || 0 ) / 60 );
        my $Duration = $Minutes < 60
            ? "$Minutes min"
            : int( $Minutes / 60 ) . ' h ' . ( $Minutes % 60 ) . ' min';

        push @Rows, {
            TicketID       => $TicketID,
            TicketNumber   => $Ticket{TicketNumber},
            Title          => $Ticket{Title},
            Customer       => $Ticket{CustomerCompanyName} || $Ticket{CustomerName} || $Ticket{CustomerID} || '-',
            Technician     => $Technician{UserFullname} || $Technician{UserLogin} || '-',
            WorkType       => $WorkType,
            Start          => $Start,
            Status         => $PausedAt ? 'Em pausa' : 'Em execução',
            StatusClass    => $PausedAt ? 'BWBPaused' : 'BWBRunning',
            Duration       => $Duration,
        };
    }

    for my $Row (@Rows) {
        $LayoutObject->Block( Name => 'BWBOpenWorkRow', Data => $Row );
    }
    if ( !@Rows ) {
        $LayoutObject->Block( Name => 'BWBOpenWorkNone' );
    }

    return $LayoutObject->Output(
        TemplateFile => 'AgentDashboardBWBOpenWork',
        Data         => { Count => scalar @Rows },
    );
}

1;
