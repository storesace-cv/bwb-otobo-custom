# --
# API JSON read-only de índice FAQ/tickets para o serviço BWB Assist (Bearer + IP).
# --
package Kernel::Modules::PublicBWBAssistIndex;

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

    my $Home = $ConfigObject->Get('Home') || '/opt/otobo';

    my $Expected = $ConfigObject->Get('BWBAssistIndex::BearerToken') || '';
    if ( !$Expected ) {
        my $TokenFile = $ConfigObject->Get('BWBAssistIndex::TokenFile')
            || "$Home/var/bwb-assist-index.token";
        if ( -r $TokenFile ) {
            if ( open my $Fh, '<', $TokenFile ) {
                local $/;
                $Expected = <$Fh> // '';
                close $Fh;
                $Expected =~ s/^\s+|\s+$//g;
            }
        }
    }

    my $Allowed = $ConfigObject->Get('BWBAssistIndex::AllowedIPs');
    if ( ref $Allowed ne 'ARRAY' || !@{$Allowed} ) {
        my $IPFile = $ConfigObject->Get('BWBAssistIndex::AllowedIPsFile')
            || "$Home/var/bwb-assist-index.allowed-ips";
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
                Message  => "BWBAssistIndex: IP recusado ($RemoteAddr).",
            );
            return $Reply->( 403, { ok => 0, error => 'forbidden', status => 403 } );
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
            Message  => "BWBAssistIndex: Bearer inválido (IP=$RemoteAddr).",
        );
        return $Reply->( 401, { ok => 0, error => 'unauthorized', status => 401 } );
    }

    my $Kind = lc( $RequestObject->GetParam( Param => 'Kind' ) || 'faq' );
    $Kind = 'faq' if $Kind ne 'faq' && $Kind ne 'ticket';

    my $Assist = $Kernel::OM->Get('Kernel::System::BWBAssist');
    my $Docs;
    if ( $Kind eq 'ticket' ) {
        $Docs = $Assist->IndexClosedTicketDocs( Limit => 400, UserID => 1 );
    }
    else {
        $Docs = $Assist->IndexFAQDocs( UserID => 1 );
    }

    $LogObject->Log(
        Priority => 'info',
        Message  => sprintf(
            'BWBAssistIndex: IP=%s Kind=%s Count=%s',
            $RemoteAddr,
            $Kind,
            scalar @{ $Docs || [] },
        ),
    );

    return $Reply->(
        200,
        {
            ok   => 1,
            kind => $Kind,
            docs => $Docs || [],
        }
    );
}

1;
