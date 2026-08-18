package Kernel::Output::HTML::TicketMenu::BWBWorkSession;

use parent 'Kernel::Output::HTML::Base';

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::BWBAccess
    Kernel::System::BWBWorkSession
    Kernel::System::Ticket
);

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{Ticket};
    return if !$Kernel::OM->Get('Kernel::System::Ticket')->TicketPermission(
        Type => 'rw', TicketID => $Param{Ticket}{TicketID}, UserID => $Self->{UserID}, LogNo => 1,
    );

    my $Work   = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Own    = $Work->ActiveGet( UserID => $Self->{UserID} );
    my $OnTicket = $Work->OpenGetByTicket( TicketID => $Param{Ticket}{TicketID} );

    if (
        $Access->IsZSResponsible( UserID => $Self->{UserID} )
        && $OnTicket
        && int( $OnTicket->{UserID} ) != int( $Self->{UserID} )
        && $Access->IsZSCollaborator( UserID => $OnTicket->{UserID} )
        )
    {
        return {
            %{ $Param{Config} },
            %{ $Param{Ticket} },
            Name        => 'Ver folha de trabalho',
            Description => 'Consultar a folha em curso da equipa (só leitura)',
            Link        => 'Action=AgentBWBWorkSession;TicketID=' . $Param{Ticket}{TicketID},
            PopupType   => 'TicketAction',
        };
    }

    return if $Own && int( $Own->{TicketID} ) != int( $Param{Ticket}{TicketID} );
    return if $OnTicket && ( !$Own || int( $Own->{SessionID} ) != int( $OnTicket->{SessionID} ) );

    return {
        %{ $Param{Config} },
        %{ $Param{Ticket} },
        Name        => $Own ? 'Terminar trabalho' : 'Iniciar trabalho',
        Description => $Own ? 'Terminar e contabilizar o trabalho' : 'Iniciar a contabilização do trabalho',
        Link        => 'Action=AgentBWBWorkSession;TicketID=' . $Param{Ticket}{TicketID},
        PopupType   => 'TicketAction',
    };
}

1;
