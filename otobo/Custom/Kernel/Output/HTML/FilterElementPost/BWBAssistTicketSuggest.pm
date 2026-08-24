# --
# Injeta âncora para o painel Documentação sugerida no AgentTicketZoom.
# --
package Kernel::Output::HTML::FilterElementPost::BWBAssistTicketSuggest;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless $Self, $Type;
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{Data};
    return if ${ $Param{Data} } !~ /id="AgentTicketZoom"/ && ${ $Param{Data} } !~ /Action=AgentTicketZoom/;

    my $TicketID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketID' ) || 0;
    return if !$TicketID;

    my $Marker = '<!--BWBAssistSuggest-->';
    return if ${ $Param{Data} } =~ /\Q$Marker\E/;

    my $HTML = qq{$Marker<div id="BWBAssistSuggest" class="WidgetSimple BWBAssistSuggestWidget" data-ticket-id="$TicketID" hidden>
  <div class="Header"><h2>Documentação sugerida</h2></div>
  <div class="Content">
    <button type="button" class="CallForAction" id="BWBAssistSuggestBtn"><span>Sugerir leituras da base de conhecimento</span></button>
    <div id="BWBAssistSuggestResult" class="BWBAssistSuggestResult"></div>
  </div>
</div>
};

    # Prefer inserting before the first sidebar widget if present; else prepend to body content.
    if ( ${ $Param{Data} } =~ s{(<div class="SidebarColumn[^"]*">)}{$1$HTML} ) {
        return 1;
    }
    ${ $Param{Data} } =~ s{(<div class="ContentColumn">)}{$HTML$1};
    return 1;
}

1;
