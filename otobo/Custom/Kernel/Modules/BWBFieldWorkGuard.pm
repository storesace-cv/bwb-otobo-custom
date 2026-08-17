package Kernel::Modules::BWBFieldWorkGuard;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Modules::BWBFieldWorkGuard - keep Field Mode on the active work sheet

=head1 DESCRIPTION

When Field Mode is on for a collaborator and a work sheet is running
(not paused), force navigation to that sheet. When paused, block starting
a second sheet / new ticket until resume or finish.

=cut

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    return if !$Self->{UserID} || !$Self->{SessionID};

    my $Action = $Self->{Action} || '';
    return if $Action =~ m{\A(?:Logout|AgentLogout)\z};

    my $FieldMode = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
    return if !$FieldMode->IsCollaborator( UserID => $Self->{UserID} );

    # Explicit mobile-standard preference escapes the Field work lock.
    my $Preference = $FieldMode->PreferenceGet( UserID => $Self->{UserID} );
    return if defined $Preference && $Preference eq '0';

    my $Work  = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
    my $Sheet = $Kernel::OM->Get('Kernel::System::BWBWorkSheet');
    my $Active = $Work->ActiveGet( UserID => $Self->{UserID} );
    return if !$Active;

    my $Draft  = $Sheet->DraftGet( SessionID => $Active->{SessionID} ) || {};
    my $Paused = $Draft->{PausedAt} ? 1 : 0;

    my $Layout = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketID = $Request->GetParam( Param => 'TicketID' ) || 0;
    my $Subaction = $Self->{Subaction} || $Request->GetParam( Param => 'Subaction' ) || '';

    # Running (not paused): only the work sheet for that ticket.
    if ( !$Paused ) {
        return if $Action eq 'AgentBWBWorkSession'
            && $TicketID
            && int($TicketID) == int( $Active->{TicketID} );

        # Allow Bootstrap/SetMode JSON used by Field JS.
        return
            if $Action eq 'AgentBWBFieldHome'
            && ( $Subaction eq 'Bootstrap' || $Subaction eq 'SetMode' );

        return $Layout->Redirect(
            OP => 'Action=AgentBWBWorkSession;TicketID=' . $Active->{TicketID},
        );
    }

    # Paused: may browse Field home, but not open a second sheet or create ticket.
    if (
        ( $Action eq 'AgentBWBFieldHome' && ( $Subaction eq 'NewTicket' || $Subaction eq 'StartWork' || $Subaction eq 'StoreTicket' ) )
        || ( $Action eq 'AgentBWBWorkSession' && int($TicketID) != int( $Active->{TicketID} ) )
        )
    {
        return $Layout->Redirect(
            OP => 'Action=AgentBWBWorkSession;TicketID=' . $Active->{TicketID},
        );
    }

    return;
}

1;
