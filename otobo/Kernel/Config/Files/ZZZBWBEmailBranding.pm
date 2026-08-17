# --
# BWB — branding Helpdesk nos e-mails de sistema (sem a palavra OTOBO no texto).
# Tags de template <OTOBO_*> mantêm-se: são placeholders internos, não marca.
# --
package Kernel::Config::Files::ZZZBWBEmailBranding;

use strict;
use warnings;
use utf8;

sub Load {
    my ( $File, $Self ) = @_;

    $Self->{CustomerPanelBodyLostPassword} = q{Olá <OTOBO_USERFIRSTNAME>,


Nova palavra-passe: <OTOBO_NEWPW>

<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>customer.pl};

    $Self->{CustomerPanelBodyLostPasswordToken} = q{Olá <OTOBO_USERFIRSTNAME>,

Você ou alguém que se faz passar por si pediu para alterar a sua palavra-passe do Helpdesk.

Se o desejar fazer, clique nesta ligação. Receberá outra mensagem de correio eletrónico com a palavra-passe.

<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>customer.pl?Action=CustomerLostPassword;Token=<OTOBO_TOKEN>

Se não solicitou uma nova palavra-passe, ignore este e-mail.};

    $Self->{CustomerPanelBodyNewAccount} = q{Olá <OTOBO_USERFIRSTNAME>,

Foi criada uma nova conta no Helpdesk para si.

Nome completo: <OTOBO_USERFIRSTNAME> <OTOBO_USERLASTNAME>
Nome de utilizador: <OTOBO_USERLOGIN>
Palavra-passe : <SENHA DE UTILIZADOR>

Pode iniciar sessão através do seguinte URL. Recomendamos-lhe que altere a sua palavra-passe
através do botão Preferências depois de iniciar a sessão.

<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>customer.pl
 };

    $Self->{NotificationSubjectLostPassword}      = 'Nova palavra-passe - Helpdesk';
    $Self->{NotificationSubjectLostPasswordToken} = 'Pedido de nova palavra-passe - Helpdesk';

    $Self->{NotificationBodyLostPassword} = q{Olá <OTOBO_USERFIRSTNAME>,


Aqui está a sua nova palavra-passe do Helpdesk.

Nova palavra-passe: <OTOBO_NEWPW>

Pode iniciar sessão em:

<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>index.pl
};

    $Self->{NotificationBodyLostPasswordToken} = q{Olá <OTOBO_USERFIRSTNAME>,

Você ou alguém que se faz passar por si pediu para alterar a sua palavra-passe do Helpdesk.

Se o desejar fazer, clique nesta ligação. Receberá outra mensagem de correio eletrónico com a palavra-passe.

<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>index.pl?Action=LostPassword;Token=<OTOBO_TOKEN>

Se não solicitou uma nova palavra-passe, ignore este e-mail.
};

    # FAQ approval (se activo): fecho do texto sem marca OTOBO.
    if ( defined $Self->{'FAQ::ApprovalBody'} && $Self->{'FAQ::ApprovalBody'} =~ /OTOBO Notification Master/ ) {
        $Self->{'FAQ::ApprovalBody'} =~ s/Your OTOBO Notification Master/Helpdesk/g;
    }

    return 1;
}

1;
