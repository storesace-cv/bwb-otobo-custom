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
        Query         => $Query,
        Summary       => '',
        AssistEnabled => $Assist->Enabled() ? 1 : 0,
        Message       => '',
    );

    if ( $Query ne '' ) {
        my $Result = $Assist->AssistWithTickets(
            UserID => $Self->{UserID},
            Query  => $Query,
        );

        if ( !$Result->{ok} || $Result->{unavailable} ) {
            $Data{Message} = $Result->{message}
                || 'O Assistente de Ajuda não está disponível. Use o menu Ajuda (pesquisa standard).';
            $Layout->Block(
                Name => 'Unavailable',
                Data => { Message => $Data{Message} },
            );
        }
        else {
            $Data{Summary} = $Result->{summary} || '';
            if ( $Data{Summary} ) {
                $Layout->Block( Name => 'Summary', Data => { Summary => $Data{Summary} } );
            }

            $Layout->Block( Name => 'DocSection' );
            my $HasFAQ = 0;
            for my $Hit ( @{ $Result->{excerpts} || [] } ) {
                $HasFAQ = 1;
                $Layout->Block(
                    Name => 'FAQHit',
                    Data => {
                        Number        => $Hit->{number}        || '',
                        Title         => $Hit->{title}         || '',
                        Category      => $Hit->{category}      || '',
                        Excerpt       => $Hit->{excerpt}       || '',
                        Justification => $Hit->{justification} || 'Sem justificação devolvida pelo serviço.',
                        ItemID        => $Hit->{item_id}       || 0,
                        URL           => $Hit->{url}           || '',
                    },
                );
            }
            if ( !$HasFAQ ) {
                $Layout->Block( Name => 'NoHits' );
            }

            my @Tickets = @{ $Result->{tickets} || [] };
            $Layout->Block( Name => 'TicketSection' );
            if (@Tickets) {
                for my $Hit (@Tickets) {
                    $Layout->Block(
                        Name => 'TicketHit',
                        Data => {
                            Number        => $Hit->{number}        || '',
                            Title         => $Hit->{title}         || '',
                            Category      => $Hit->{category}      || '',
                            Excerpt       => $Hit->{excerpt}       || '',
                            Justification => $Hit->{justification} || 'Sem justificação devolvida pelo serviço.',
                            TicketID      => $Hit->{ticket_id}     || 0,
                            URL           => $Hit->{url}           || '',
                        },
                    );
                }
            }
            else {
                $Layout->Block( Name => 'NoTicketHits' );
            }
        }
    }
    else {
        $Layout->Block( Name => 'Intro' );
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
