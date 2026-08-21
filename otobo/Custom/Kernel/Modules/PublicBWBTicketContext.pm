# --
# API JSON read-only de contexto de ticket para Claude Mail MCP (Bearer).
# --
package Kernel::Modules::PublicBWBTicketContext;

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
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $RequestObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');

    my $Reply = sub {
        my ( $Status, $Data ) = @_;
        my $JSON = $LayoutObject->JSONEncode( Data => $Data );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=utf-8',
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    };

    my $Expected = $ConfigObject->Get('BWBTicketContext::BearerToken') || '';
    if ( !$Expected ) {
        my $TokenFile = $ConfigObject->Get('BWBTicketContext::TokenFile')
            || ( ( $ConfigObject->Get('Home') || '/opt/otobo' ) . '/var/bwb-ticket-context.token' );
        if ( -r $TokenFile ) {
            if ( open my $Fh, '<', $TokenFile ) {
                local $/;
                $Expected = <$Fh> // '';
                close $Fh;
                $Expected =~ s/^\s+|\s+$//g;
            }
        }
    }

    my $Allowed = $ConfigObject->Get('BWBTicketContext::AllowedIPs');
    if ( ref $Allowed ne 'ARRAY' || !@{$Allowed} ) {
        my $IPFile = $ConfigObject->Get('BWBTicketContext::AllowedIPsFile')
            || ( ( $ConfigObject->Get('Home') || '/opt/otobo' ) . '/var/bwb-ticket-context.allowed-ips' );
        if ( -r $IPFile ) {
            if ( open my $Fh, '<', $IPFile ) {
                my @IPs;
                while ( my $Line = <$Fh> ) {
                    chomp $Line;
                    $Line =~ s/#.*//;
                    $Line =~ s/^\s+|\s+$//g;
                    push @IPs, $Line if $Line ne '';
                }
                close $Fh;
                $Allowed = \@IPs;
            }
        }
    }
    $Allowed = [] if ref $Allowed ne 'ARRAY';

    my $RemoteAddr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR} || '';
    $RemoteAddr =~ s/\s//g;
    if ( $RemoteAddr =~ /,/ ) {
        ($RemoteAddr) = split /,/, $RemoteAddr;
    }

    if ( @{$Allowed} ) {
        my $OK = 0;
        for my $IP ( @{$Allowed} ) {
            next if !defined $IP || $IP eq '';
            if ( $RemoteAddr eq $IP ) {
                $OK = 1;
                last;
            }
        }
        if ( !$OK ) {
            $LogObject->Log(
                Priority => 'notice',
                Message  => "BWBTicketContext: IP recusado ($RemoteAddr).",
            );
            return $Reply->(
                403,
                { ok => 0, error => 'forbidden', status => 403 },
            );
        }
    }

    my $Auth = $ENV{HTTP_AUTHORIZATION} || $ENV{REDIRECT_HTTP_AUTHORIZATION} || '';
    if ( !$Auth ) {
        $Auth = $RequestObject->HTTP('AUTHORIZATION') || '';
    }
    my ($Bearer) = $Auth =~ /^Bearer\s+(\S+)/i;
    $Bearer //= $RequestObject->GetParam( Param => 'Token' ) || '';

    if ( !$Expected || !$Bearer || $Bearer ne $Expected ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => "BWBTicketContext: Bearer inválido (IP=$RemoteAddr).",
        );
        return $Reply->(
            401,
            { ok => 0, error => 'unauthorized', status => 401 },
        );
    }

    my $TicketNumber = $RequestObject->GetParam( Param => 'TicketNumber' ) || '';
    my $TicketID     = $RequestObject->GetParam( Param => 'TicketID' )     || '';
    $TicketNumber =~ s/^\s+|\s+$//g;
    $TicketID =~ s/^\s+|\s+$//g;

    if ( !$TicketNumber && !$TicketID ) {
        return $Reply->(
            400,
            { ok => 0, error => 'need_ticket_number_or_id', status => 400 },
        );
    }

    my $Context = $Kernel::OM->Get('Kernel::System::BWBEmailContext')->ContextForTicket(
        TicketNumber => $TicketNumber,
        TicketID     => $TicketID,
    );

    $LogObject->Log(
        Priority => 'info',
        Message  => sprintf(
            'BWBTicketContext: IP=%s TicketNumber=%s TicketID=%s ok=%s',
            $RemoteAddr,
            $TicketNumber || '-',
            $TicketID     || '-',
            $Context->{ok} ? '1' : '0',
        ),
    );

    return $Reply->( $Context->{status} || 200, $Context );
}

1;
