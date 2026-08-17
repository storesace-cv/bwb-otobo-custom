package Kernel::Modules::BWBAgentSessionGuard;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Modules::BWBAgentSessionGuard - exclusive Agent session for collaborators

=head1 DESCRIPTION

Collaborators (field technicians) may only be authenticated on one Agent
device at a time. On every request, other AgentInterface sessions for the
same UserID are removed. Responsible agents / admins are not affected.

Registered as PreApplicationModule (method PreRun).

=cut

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    return if !$Self->{UserID} || !$Self->{SessionID};
    return if ( $Self->{Action} || '' ) =~ m{\A(?:Logout|AgentLogout)\z};

    my $FieldMode = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
    return if !$FieldMode->IsCollaborator( UserID => $Self->{UserID} );

    my $AuthSession = $Kernel::OM->Get('Kernel::System::AuthSession');
    my @SessionIDs  = $AuthSession->GetAllSessionIDs();

    SESSION:
    for my $SessionID (@SessionIDs) {
        next SESSION if !$SessionID;
        next SESSION if $SessionID eq $Self->{SessionID};

        my %Data = $AuthSession->GetSessionIDData( SessionID => $SessionID );
        next SESSION if !%Data;
        next SESSION if ( $Data{SessionSource} || '' ) ne 'AgentInterface';
        next SESSION if !$Data{UserID} || int( $Data{UserID} ) != int( $Self->{UserID} );

        $AuthSession->RemoveSessionID( SessionID => $SessionID );
    }

    return;
}

1;
