package Kernel::Language::pt_ZZZBWBStates;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    my %Translation = (
        'Pendente até determinada data' => 'Pendente com Agendamento',
    );

    $Self->{Translation} = {
        %{ $Self->{Translation} || {} },
        %Translation,
    };

    return 1;
}

1;
