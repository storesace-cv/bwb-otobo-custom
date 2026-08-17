# --
# BWB / StoresAce — session policy for Field Mode collaborators.
# Loaded after ZZZAAuto so these values win over SysConfig DB defaults.
# --
package Kernel::Config::Files::ZZZBWBSession;

use strict;
use warnings;
use utf8;

sub Load {
    my ( $File, $Self ) = @_;

    # 20 minutes idle (Field technicians on mobile).
    $Self->{SessionMaxIdleTime} = 1200;

    # Mobile networks change IP constantly; RemoteIP check caused spurious logouts.
    $Self->{SessionCheckRemoteIP} = 0;

    # Agent header logo: black compact mark (readable on light chrome).
    if ( ref $Self->{AgentLogo} eq 'HASH' ) {
        $Self->{AgentLogo}->{URL} = 'common/img/bwb-black-compact.svg';
    }
    else {
        $Self->{AgentLogo} = {
            URL         => 'common/img/bwb-black-compact.svg',
            StyleHeight => '60px',
            StyleWidth  => '162px',
            StyleTop    => '6px',
            StyleRight  => '24px',
        };
    }

    return 1;
}

1;
