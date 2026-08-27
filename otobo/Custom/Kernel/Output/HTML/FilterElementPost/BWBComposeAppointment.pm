# --
# Injeta o bloco «Agendar no calendário» junto a NextState no Compose / Pending.
# --

package Kernel::Output::HTML::FilterElementPost::BWBComposeAppointment;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::BWBAppointmentCheck',
    'Kernel::System::State',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless $Self, $Type;
    $Self->{Action} = $Param{Action} || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Data};
    return 1 if $Self->{Action} ne 'AgentTicketCompose'
        && $Self->{Action} ne 'AgentTicketPending';

    my $Marker = '<!--BWBComposeAppointment-->';
    return 1 if ${ $Param{Data} } =~ /\Q$Marker\E/;
    return 1 if ${ $Param{Data} } !~ /id=["']StateID["']/;

    my $TicketID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketID' ) || 0;
    return 1 if !$TicketID;

    my $Check     = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    my $StateName = $Check->PendingScheduledState();
    my $Layout = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my %StateList = $Kernel::OM->Get('Kernel::System::State')->StateList(
        UserID => $Layout->{UserID} || 1,
        Valid  => 1,
    );
    my $StateID = 0;
    for my $ID ( keys %StateList ) {
        if ( ( $StateList{$ID} || '' ) eq $StateName ) {
            $StateID = 0 + $ID;
            last;
        }
    }
    return 1 if !$StateID;

    my $HasFuture = $Check->HasFutureAppointment( TicketID => $TicketID ) ? 1 : 0;
    my $StartUTC  = $Check->NextFutureStart( TicketID => $TicketID ) || '';
    my $StartLabel = '';
    if ($StartUTC) {
        my $StartObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { String => $StartUTC, TimeZone => 'UTC' },
        );
        if ($StartObject) {
            $StartObject->ToTimeZone( TimeZone => $Layout->{UserTimeZone} || 'Europe/Lisbon' );
            $StartLabel = $StartObject->Format( Format => '%d/%m/%Y %H:%M' );
        }
    }

    my $StatusClass = $HasFuture ? 'BWBAppointmentOk' : 'BWBAppointmentMissing';
    my $StatusText  = $HasFuture
        ? ( 'Marcação registada' . ( $StartLabel ? " — $StartLabel" : '' ) )
        : 'Ainda sem marcação futura';

    # Escape for HTML attribute/text (labels are agent-controlled dates only).
    $StatusText =~ s{&}{&amp;}g;
    $StatusText =~ s{<}{&lt;}g;
    $StatusText =~ s{>}{&gt;}g;

    my $HTML = qq{$Marker
<style type="text/css">
.BWBAppointmentStatus{display:inline-block;margin-top:8px;padding:8px 12px;border-radius:8px;font-weight:700}
.BWBAppointmentOk{background:#e9f8ee;color:#176b36}
.BWBAppointmentMissing{background:#fff1dd;color:#8a4b00}
#AppointmentSchedule .CallForAction{margin-top:10px}
</style>
<div id="AppointmentSchedule" class="Row" style="display:none">
<label>Agendamento</label>
<div>
<button type="button" class="CallForAction Primary" id="BWBScheduleAppointment"><span>Agendar no calendário</span></button>
<div id="BWBAppointmentStatus" class="BWBAppointmentStatus $StatusClass">$StatusText</div>
</div>
</div>
};

    $Layout->AddJSData(
        Key   => 'TicketID',
        Value => 0 + $TicketID,
    );
    $Layout->AddJSData(
        Key   => 'BWBPendingScheduledStateID',
        Value => 0 + $StateID,
    );
    $Layout->AddJSData(
        Key   => 'BWBHasFutureAppointment',
        Value => $HasFuture,
    );

    # Insert after the StateID row when possible; else after the StateID select.
    if (
        ${ $Param{Data} } =~ s{
            (
                <div\s+class="Row"[^>]*>
                (?:(?!</div>).)*?
                id=["']StateID["']
                (?:(?!</div>).)*?
                </div>
            )
        }{$1$HTML}xsi
        )
    {
        return 1;
    }

    ${ $Param{Data} } =~ s{(<select\b[^>]*\bid=["']StateID["'][^>]*>.*?</select>)}{$1$HTML}xsi;
    return 1;
}

1;
