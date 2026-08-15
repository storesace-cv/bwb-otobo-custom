package Kernel::Output::HTML::TicketMenu::BWBConvertCustomer;
use parent 'Kernel::Output::HTML::Base';
use strict;
use warnings;
our @ObjectDependencies = qw(Kernel::System::BWBConvertCustomer);
sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{Ticket};
    return if !$Kernel::OM->Get('Kernel::System::BWBConvertCustomer')->Allowed(
        TicketID => $Param{Ticket}->{TicketID}, UserID => $Self->{UserID},
    );
    return {
        %{ $Param{Config} }, %{ $Param{Ticket} },
        Name => 'Converter remetente em cliente', Description => 'Criar cliente, Sede e utilizador a partir deste remetente',
        Link => 'Action=AgentBWBConvertCustomer;TicketID=' . $Param{Ticket}->{TicketID}, PopupType => 'TicketAction',
    };
}
1;
