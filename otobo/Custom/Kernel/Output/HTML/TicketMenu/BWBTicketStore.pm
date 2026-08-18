package Kernel::Output::HTML::TicketMenu::BWBTicketStore;

use parent 'Kernel::Output::HTML::Base';

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
);

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{Ticket}{TicketID} || !$Self->{UserID};
    return if !$Param{Ticket}{CustomerID};
    return if !$Kernel::OM->Get('Kernel::System::BWBAccess')->TicketAccessCheck(
        UserID   => $Self->{UserID},
        TicketID => $Param{Ticket}{TicketID},
    );

    return {
        %{ $Param{Config} },
        Name        => 'Alterar loja',
        Description => 'Alterar a loja deste ticket sem mudar a ficha do utilizador de cliente.',
        Link        => 'Action=AgentBWBTicketStore;TicketID=' . $Param{Ticket}{TicketID},
        PopupType   => '',
    };
}

1;
