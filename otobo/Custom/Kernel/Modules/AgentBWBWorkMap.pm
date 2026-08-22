package Kernel::Modules::AgentBWBWorkMap;

use strict;
use warnings;
use utf8;

our $ObjectDependencies = [
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::JSON',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request',
];

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {%Param};
    bless( $Self, $Type );
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');

    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' ) || 0;
    if ( !$TicketID ) {
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $JSONObject->Encode( Data => { Success => 0, Error => 'TicketID em falta.' } ),
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $TicketID,
        UserID   => $Self->{UserID},
    );
    if ( !$Access ) {
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $JSONObject->Encode( Data => { Success => 0, Error => 'Sem permissão.' } ),
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=utf-8',
        Content     => $JSONObject->Encode( Data => { Success => 0, Error => 'Erro de base de dados.' } ),
        Type        => 'inline',
        NoCache     => 1,
    ) if !$DBObject->Prepare(
        SQL => q{
            SELECT article_id, finish_latitude, finish_longitude, finish_location_source, finish_accuracy_m
            FROM bwb_work_session
            WHERE ticket_id = ?
              AND end_time IS NOT NULL
              AND finish_latitude IS NOT NULL
              AND finish_longitude IS NOT NULL
              AND article_id IS NOT NULL
            ORDER BY id
        },
        Bind => [ \$TicketID ],
    );

    my @Locations;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Locations, {
            ArticleID => 0 + $Row[0],
            Latitude  => '' . $Row[1],
            Longitude => '' . $Row[2],
            Source    => $Row[3] // '',
            Accuracy  => defined $Row[4] ? '' . $Row[4] : '',
        };
    }

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=utf-8',
        Content     => $JSONObject->Encode(
            Data => {
                Success   => 1,
                Locations => \@Locations,
            }
        ),
        Type    => 'inline',
        NoCache => 1,
    );
}

1;
