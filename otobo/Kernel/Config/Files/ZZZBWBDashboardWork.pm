package Kernel::Config::Files::ZZZBWBDashboardWork;
use strict;
use warnings;
use utf8;

sub Load {
    my ( $File, $Self ) = @_;

    $Self->{'DashboardBackend'}->{'0125-BWBOpenWork'} = {
        Block       => 'ContentLarge',
        CacheTTLLocal => '0',
        Default     => '1',
        Description => 'Folhas de trabalho em execução ou em pausa.',
        Group       => '',
        Module      => 'Kernel::Output::HTML::Dashboard::BWBOpenWork',
        Permission  => 'rw',
        Title       => 'Folhas de trabalho abertas',
    };
    return 1;
}
1;
