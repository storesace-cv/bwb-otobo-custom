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
<div id="AppointmentSchedule" class="BWBAppointmentBlock" style="display:none">
<label class="BWBAppointmentLabel">Agendamento</label>
<div class="BWBAppointmentBody">
<button type="button" class="CallForAction Primary" id="BWBScheduleAppointment"><span>Agendar no calendário</span></button>
<div id="BWBAppointmentStatus" class="BWBAppointmentStatus $StatusClass">$StatusText</div>
</div>
</div>
};

    # Marca a linha nativa «Data da pendência» para ocultar quando o agendamento é via calendário.
    ${ $Param{Data} } =~ s{
        (<div)\s+class="Row"([^>]*>\s*
         <label[^>]*>[^<]*(?:pend[êe]ncia|Pending\s+date)[^<]*</label>)
    }{$1 id="BWBNativePendingRow" class="Row"$2}xsi;

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
