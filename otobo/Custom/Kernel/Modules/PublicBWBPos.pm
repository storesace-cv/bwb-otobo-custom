# --
# API pública POS Helpdesk: Ping, Auth, Directory, Enroll, Ticket.
# --
package Kernel::Modules::PublicBWBPos;

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

    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $RequestObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');
    my $Pos           = $Kernel::OM->Get('Kernel::System::BWBPosDevice');

    my $Reply = sub {
        my ( $Status, $Data ) = @_;
        $Data ||= {};
        $Data->{status} = $Status if !exists $Data->{status};
        my $JSON = $LayoutObject->JSONEncode( Data => $Data );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    };

    my $Payload = $Self->_Payload($RequestObject, $JSONObject);
    my $Action  = $Self->{Subaction} || $Payload->{Subaction} || 'Ping';

    if ( $Action eq 'Ping' ) {
        return $Reply->( 200, { ok => 1, service => 'pos' } );
    }

    if ( $Action eq 'Auth' ) {
        my $Result = $Pos->AuthAgent(
            User     => $Payload->{User} || $Payload->{Login},
            Password => $Payload->{Password} || $Payload->{Pw},
        );
        return $Reply->( $Result->{status} || 400, $Result );
    }

    if ( $Action eq 'Directory' ) {
        my $UserID = $Pos->SessionUserID( SessionToken => $Payload->{SessionToken} );
        return $Reply->( 401, { ok => 0, error => 'unauthorized' } ) if !$UserID;
        my $Result = $Pos->Directory(
            UserID     => $UserID,
            Level      => $Payload->{Level} || 'customers',
            CustomerID => $Payload->{CustomerID},
            StoreID    => $Payload->{StoreID},
        );
        return $Reply->( $Result->{status} || 400, $Result );
    }

    if ( $Action eq 'Enroll' ) {
        my $UserID = $Pos->SessionUserID( SessionToken => $Payload->{SessionToken} );
        return $Reply->( 401, { ok => 0, error => 'unauthorized' } ) if !$UserID;
        my $Result = $Pos->Enroll(
            UserID        => $UserID,
            SessionToken  => $Payload->{SessionToken},
            CustomerID    => $Payload->{CustomerID},
            StoreID       => $Payload->{StoreID},
            CustomerUser  => $Payload->{CustomerUser},
            StationNumber => $Payload->{StationNumber},
            License       => $Payload->{License},
            PosVersion    => $Payload->{PosVersion},
            PosRelease    => $Payload->{PosRelease},
            Hostname      => $Payload->{Hostname},
        );
        return $Reply->( $Result->{status} || 400, $Result );
    }

    if ( $Action eq 'Ticket' ) {
        my $Bearer = $Self->_Bearer($RequestObject) || $Payload->{DeviceToken} || '';
        my $Logs;
        if ( $Payload->{LogsB64} ) {
            $Logs = $Self->_B64( $Payload->{LogsB64} );
        }
        my $Result = $Pos->TicketCreate(
            DeviceToken   => $Bearer,
            Title         => $Payload->{Title},
            Body          => $Payload->{Body},
            StationNumber => $Payload->{StationNumber},
            License       => $Payload->{License},
            PosVersion    => $Payload->{PosVersion},
            PosRelease    => $Payload->{PosRelease},
            Hostname      => $Payload->{Hostname},
            LogsBytes     => $Logs,
        );
        return $Reply->( $Result->{status} || 400, $Result );
    }

    return $Reply->( 400, { ok => 0, error => 'bad_action' } );
}

sub _Bearer {
    my ( $Self, $RequestObject ) = @_;
    my $Auth = $ENV{HTTP_AUTHORIZATION} || $ENV{REDIRECT_HTTP_AUTHORIZATION} || '';
    if ( !$Auth ) {
        $Auth = $RequestObject->HTTP('AUTHORIZATION') || '';
    }
    my ($Bearer) = $Auth =~ /^Bearer\s+(\S+)/i;
    return $Bearer || '';
}

sub _Payload {
    my ( $Self, $RequestObject, $JSONObject ) = @_;
    my %Data;
    for my $Key (
        qw(User Login Password Pw SessionToken CustomerID StoreID CustomerUser
        Title Body StationNumber License PosVersion PosRelease Hostname LogsB64
        Subaction Level DeviceToken Payload)
        )
    {
        my $Value = $RequestObject->GetParam( Param => $Key );
        $Data{$Key} = $Value if defined $Value && $Value ne '';
    }
    if ( $Data{Payload} ) {
        my $Decoded = $JSONObject->Decode( Data => $Data{Payload} );
        if ( ref $Decoded eq 'HASH' ) {
            %Data = ( %Data, %{$Decoded} );
        }
        delete $Data{Payload};
    }
    return \%Data;
}

sub _B64 {
    my ( $Self, $Raw ) = @_;
    return if !$Raw;
    $Raw =~ s/\s+//g;
    return if $Raw !~ m{^[A-Za-z0-9+/]+={0,2}$};
    return if length($Raw) > 2_200_000;
    require MIME::Base64;
    my $Bin = MIME::Base64::decode_base64($Raw);
    return if !$Bin;
    return if length($Bin) > 1_572_864;
    return if substr( $Bin, 0, 2 ) ne 'PK';
    return $Bin;
}

1;
