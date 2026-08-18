package Kernel::Modules::AgentTicketEmail;

use strict;
use warnings;
use utf8;

use Kernel::Modules::BWBTicketIntakeAgent;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return Kernel::Modules::BWBTicketIntakeAgent::Run(
        $Self,
        Origin       => 'email',
        ScreenTitle  => 'Novo Registo por E-mail',
        TemplateFile => 'AgentTicketEmail',
        SubmitLabel  => 'Registar',
        %Param,
    );
}

1;
