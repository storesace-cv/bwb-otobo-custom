# --
# Assistente de pesquisa na Ajuda (FAQ) + casos semelhantes.
# --
package Kernel::Modules::AgentBWBAssist;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Layout  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Assist  = $Kernel::OM->Get('Kernel::System::BWBAssist');

    my $Subaction = $Self->{Subaction} || $Request->GetParam( Param => 'Subaction' ) || '';
    my $Query     = $Request->GetParam( Param => 'Query' ) || '';
    $Query =~ s/^\s+|\s+$//g;

    if ( $Subaction eq 'SuggestFromTicket' || $Subaction eq 'JSONSuggest' ) {
        my $TicketID = $Request->GetParam( Param => 'TicketID' ) || 0;
        my $Result   = $Assist->SuggestFromTicket(
            UserID   => $Self->{UserID},
            TicketID => $TicketID,
        );
        return $Layout->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $Layout->JSONEncode( Data => $Result ),
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    if ( $Subaction eq 'JSONSearch' ) {
        my $Result = $Assist->AssistWithTickets(
            UserID => $Self->{UserID},
            Query  => $Query,
        );
        return $Layout->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $Layout->JSONEncode( Data => $Result ),
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    my %Data = (
        Query          => $Query,
        Summary        => '',
        Mode           => '',
        Warning        => '',
        HasResults     => 0,
        HasTickets     => 0,
        AssistEnabled  => $Assist->Enabled() ? 1 : 0,
    );

    if ( $Query ne '' ) {
        my $Result = $Assist->AssistWithTickets(
            UserID => $Self->{UserID},
            Query  => $Query,
        );
        $Data{Summary} = $Result->{summary} || '';
        $Data{Mode}    = $Result->{mode}    || '';
        $Data{Warning} = $Result->{warning} || '';

        for my $Hit ( @{ $Result->{excerpts} || [] } ) {
            $Data{HasResults} = 1;
            $Layout->Block(
                Name => 'FAQHit',
                Data => {
                    Number   => $Hit->{number}   || '',
                    Title    => $Hit->{title}    || '',
                    Category => $Hit->{category} || '',
                    Excerpt  => $Hit->{excerpt}  || '',
                    ItemID   => $Hit->{item_id}  || 0,
                    URL      => $Hit->{url}      || '',
                },
            );
        }
        for my $Hit ( @{ $Result->{tickets} || [] } ) {
            $Data{HasTickets} = 1;
            my $TicketID = $Hit->{ticket_id} || 0;
            $Layout->Block(
                Name => 'TicketHit',
                Data => {
                    Number   => $Hit->{number}   || '',
                    Title    => $Hit->{title}    || '',
                    Category => $Hit->{category} || '',
                    Excerpt  => $Hit->{excerpt}  || '',
                    TicketID => $TicketID,
                    URL      => $Hit->{url}      || '',
                },
            );
        }
        if ( !$Data{HasResults} && !$Data{HasTickets} ) {
            $Layout->Block( Name => 'NoHits' );
        }
    }
    else {
        $Layout->Block( Name => 'Intro' );
    }

    if ( $Data{Warning} ) {
        $Layout->Block( Name => 'Warning', Data => { Warning => $Data{Warning} } );
    }
    if ( $Data{Summary} ) {
        $Layout->Block( Name => 'Summary', Data => { Summary => $Data{Summary} } );
    }

    my $Output = $Layout->Header( Title => 'Assistente de Ajuda' );
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentBWBAssist',
        Data         => \%Data,
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
