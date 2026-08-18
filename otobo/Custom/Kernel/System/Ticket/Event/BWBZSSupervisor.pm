package Kernel::System::Ticket::Event::BWBZSSupervisor;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBTicketIntake',
    'Kernel::System::BWBWorkSession',
    'Kernel::System::BWBZSSupervisorNotify',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my $Event    = $Param{Event} || '';
    my $TicketID = $Param{Data}->{TicketID} || 0;
    my $UserID   = $Param{UserID} || 0;
    return 1 if !$TicketID || !$UserID;

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');

    if ( $Event eq 'TicketCreate' ) {
        my $Intake = $Kernel::OM->Get('Kernel::System::BWBTicketIntake');
        return 1 if $Intake->IsSupervisorNotifySkipped();
        $Kernel::OM->Get('Kernel::System::BWBZSSupervisorNotify')->Notify(
            TicketID    => $TicketID,
            ActorUserID => $UserID,
            Kind        => 'TicketCreate',
        );
        return 1;
    }

    return 1 if $Event ne 'TicketOwnerUpdate';

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return 1 if !%Ticket;
    my $NewOwnerID = $Ticket{OwnerID} || 0;
    return 1 if !$NewOwnerID;
    return 1 if !$Access->IsZSCollaborator( UserID => $NewOwnerID );

    my $Work    = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
    my $Session = $Work->OpenGetByTicket( TicketID => $TicketID );
    return 1 if !$Session;
    return 1 if int( $Session->{UserID} ) == int($NewOwnerID);
    # Only leftover sheets of the ZS responsible (Amadeu). Never steal a
    # collaborator's running session when the ticket is reassigned.
    return 1 if !$Access->IsZSResponsible( UserID => $Session->{UserID} );

    if ( !$Work->TransferToUser( SessionID => $Session->{SessionID}, NewUserID => $NewOwnerID ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "BWBZSSupervisor: não foi possível ceder a folha do ticket $TicketID ao utilizador $NewOwnerID (já tem outra sessão ativa?).",
        );
        return 1;
    }

    $Kernel::OM->Get('Kernel::System::Ticket')->HistoryAdd(
        TicketID     => $TicketID,
        HistoryType  => 'AddNote',
        Name         => 'Folha de trabalho cedida ao novo proprietário (ZS Angola).',
        CreateUserID => $UserID,
    );
    return 1;
}

1;
