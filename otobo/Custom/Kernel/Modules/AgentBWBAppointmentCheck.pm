# --
# JSON: marcação futura ligada ao ticket (folha, Compose, Pending).
# --

package Kernel::Modules::AgentBWBAppointmentCheck;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Layout  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Ticket  = $Kernel::OM->Get('Kernel::System::Ticket');

    my $TicketID = $Request->GetParam( Param => 'TicketID' ) || 0;
    if ( !$TicketID ) {
        return $Self->_JSON(
            Layout => $Layout,
            Data   => { Success => 0, Error => 'Ticket inválido.' },
        );
    }

    if (
        !$Ticket->TicketPermission(
            Type     => 'ro',
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
            LogNo    => 1,
        )
        )
    {
        return $Self->_JSON(
            Layout => $Layout,
            Data   => { Success => 0, Error => 'Sem permissão.' },
        );
    }

    my $Check    = $Kernel::OM->Get('Kernel::System::BWBAppointmentCheck');
    my $StartUTC = $Check->NextFutureStart( TicketID => $TicketID ) || '';
    my $StartLabel = '';
    if ($StartUTC) {
        my $StartObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { String => $StartUTC, TimeZone => 'UTC' },
        );
        if ($StartObject) {
            my %Viewer = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                UserID => $Self->{UserID},
            );
            $StartObject->ToTimeZone( TimeZone => $Viewer{UserTimeZone} || 'Europe/Lisbon' );
            $StartLabel = $StartObject->Format( Format => '%d/%m/%Y %H:%M' );
        }
    }

    return $Self->_JSON(
        Layout => $Layout,
        Data   => {
            Success              => 1,
            HasFutureAppointment => $Check->HasFutureAppointment( TicketID => $TicketID ) ? 1 : 0,
            StartTime            => $StartUTC,
            StartTimeLabel       => $StartLabel,
        },
    );
}

sub _JSON {
    my ( $Self, %Param ) = @_;
    my $Layout = $Param{Layout} || return;
    my $JSON   = $Kernel::OM->Get('Kernel::System::JSON')->Encode( Data => $Param{Data} || {} );
    return $Layout->Attachment(
        ContentType => 'application/json; charset=UTF-8',
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
