# --
# Override: antes do AgentDashboardCommon, encaixa widgets novos na ordem
# canónica (prefixo SysConfig), em vez de os mandar sempre para o fundo.
# --
package Kernel::Modules::AgentDashboard;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::Modules::AgentDashboardCommon);

our @ObjectDependencies = (
    'Kernel::System::BWBDashboard',
);

sub Run {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Kernel::System::BWBDashboard')->AgentPositionEnsure(
        UserID    => $Self->{UserID},
        SessionID => $Self->{SessionID},
        Session   => $Self->{Session},
    );

    return $Self->SUPER::Run(%Param);
}

1;
