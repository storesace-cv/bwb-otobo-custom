package Kernel::Output::HTML::FilterElementPost::BWBWorkMapEmbedKey;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
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

    return 1 if $Self->{Action} ne 'AgentTicketZoom';

    my $Key = $Kernel::OM->Get('Kernel::Config')->Get('BWB::MapsEmbedAPIKey') // '';
    $Key =~ s{\s+}{}g;

    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->AddJSData(
        Key   => 'BWBMapsEmbedAPIKey',
        Value => $Key,
    );

    return 1;
}

1;
