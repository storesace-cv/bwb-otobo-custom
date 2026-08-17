package Kernel::Output::HTML::TicketMenu::BWBAddCustomerEmail;

use parent 'Kernel::Output::HTML::Base';

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBConvertCustomer',
    'Kernel::System::BWBCustomerUserEmail',
);

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{Ticket}{TicketID} || !$Self->{UserID};
    return if !$Kernel::OM->Get('Kernel::System::BWBAccess')->TicketAccessCheck(
        UserID   => $Self->{UserID},
        TicketID => $Param{Ticket}{TicketID},
    );

    my $Sender = $Kernel::OM->Get('Kernel::System::BWBConvertCustomer')->SenderGet(
        TicketID => $Param{Ticket}{TicketID},
    );
    return if !$Sender->{Email};

    my $Existing = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail')->CustomerUserDataGetByEmail(
        Email => $Sender->{Email},
    );
    return if $Existing;

    return {
        %{ $Param{Config} },
        Name        => 'Associar e-mail a utilizador de cliente',
        Description => 'Regista o remetente como endereço adicional de receção de um utilizador de cliente.',
        Link        => 'Action=AgentBWBAddCustomerEmail;TicketID=' . $Param{Ticket}{TicketID},
        # The ticket menu schema defaults this to TicketAction.  Keep the
        # link in the current ticket zoom so the JavaScript can open its
        # native in-page dialog instead of a separate browser tab.
        PopupType   => '',
    };
}

1;
