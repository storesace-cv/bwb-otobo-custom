package Kernel::Config::Files::ZZZBWBAjuda;

use strict;
use warnings;
use utf8;

sub Load {
    my ( $File, $Self ) = @_;

    $Self->{'Loader::Agent::CommonJS'}->{'999-BWBAjudaOrder'} = [
        'Core.Agent.BWBAjudaOrder.js',
    ];

    # Keep the internal NavBar identifier "FAQ" intact. Only change the
    # user-facing labels, otherwise the registered submenu links stop grouping.
    for my $Navigation (
        [ 'Frontend::Navigation',         'AgentFAQExplorer',    '002-FAQ' ],
        [ 'CustomerFrontend::Navigation', 'CustomerFAQExplorer', '002-FAQ' ],
    ) {
        my ( $Root, $Action, $Key ) = @{$Navigation};
        my $Entries = $Self->{$Root}->{$Action}->{$Key};
        next if ref $Entries ne 'ARRAY';

        for my $Entry ( @{$Entries} ) {
            next if ref $Entry ne 'HASH';
            if ( ( $Entry->{Type} || '' ) eq 'Menu' ) {
                $Entry->{Name}        = 'Ajuda';
                $Entry->{Description} = 'Área de ajuda';
            }
        }
    }

    my $Public = $Self->{'PublicFrontend::Navigation'}->{'PublicFAQExplorer'}->{'002-FAQ'};
    if ( ref $Public eq 'ARRAY' ) {
        for my $Entry ( @{$Public} ) {
            next if ref $Entry ne 'HASH';
            $Entry->{Name}        = 'Ajuda';
            $Entry->{Description} = 'Área de ajuda';
        }
    }

    return 1;
}

1;
