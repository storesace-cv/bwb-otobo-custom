package Kernel::Config::Files::ZZZBWBTicketStore;
use strict;
use warnings;
use utf8;

sub Load {
    my ( $File, $Self ) = @_;

    # Espelho de apresentação: preenchido só por BWBTicketStore->Set.
    $Self->{'Ticket::Frontend::AgentTicketZoom'}->{DynamicField}->{BWBStore} = 1;

    return 1;
}

1;
