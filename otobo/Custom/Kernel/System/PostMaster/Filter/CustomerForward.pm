package Kernel::System::PostMaster::Filter::CustomerForward;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBCustomerUserEmail',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = bless {}, $Type;
    $Self->{ParserObject} = $Param{ParserObject} || die 'Got no ParserObject!';
    $Self->{CommunicationLogObject}
        = $Param{CommunicationLogObject} || die 'Got no CommunicationLogObject!';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{GetParam} || !$Param{JobConfig};
    return 1 if $Param{TicketID};

    my $GetParam = $Param{GetParam};
    my $Subject  = $GetParam->{Subject} // '';

    # Required syntax: customer number | customer-user email | original subject.
    return 1 if $Subject !~ m{\A\s*([^|]+?)\s*\|\s*([^|\s]+\@[^|\s]+)\s*\|\s*(.+?)\s*\z};

    my ( $CustomerNo, $CustomerEmail, $CleanSubject ) = ( $1, lc $2, $3 );
    $CustomerNo =~ s{\A\s+|\s+\z}{}g;

    my @FromAddresses = $Self->{ParserObject}->SplitAddressLine( Line => $GetParam->{From} // '' );
    my $ForwarderEmail = '';
    for my $Address (@FromAddresses) {
        $ForwarderEmail = lc( $Self->{ParserObject}->GetEmailAddress( Email => $Address ) // '' );
    }

    my ($ForwarderDomain) = $ForwarderEmail =~ m{\@([a-z0-9.-]+)\z};
    my %AllowedDomain = map { $_ => 1 } qw(bwb.pt storesace.cv zsangola.com zsa-softwares.com);
    my %AllowedAddress = map { $_ => 1 } qw(amadeu.cristelo@gmail.com);
    return 1 if !$AllowedAddress{$ForwarderEmail}
        && ( !$ForwarderDomain || !$AllowedDomain{$ForwarderDomain} );

    my $Authentication = join "\n", map { $GetParam->{$_} // '' }
        qw(Authentication-Results ARC-Authentication-Results);
    my $DomainQuoted = quotemeta $ForwarderDomain;
    my $AuthenticatedByResults =
           $Authentication =~ m{dmarc=pass\b[^\n]*(?:header\.from|from)\s*=\s*$DomainQuoted\b}i
        || $Authentication =~ m{dkim=pass\b[^\n]*(?:header\.d|d)\s*=\s*$DomainQuoted\b}i
        || $Authentication =~ m{spf=pass\b[^\n]*(?:smtp\.mailfrom|mailfrom)\s*=\s*[^\s;<>]*\@$DomainQuoted\b}i;

    my $SpamStatus = $GetParam->{'X-Spam-Status'} // '';
    my $ReturnPath = lc( $GetParam->{'Return-Path'} // '' );
    my $AuthenticatedByMailbox =
           $SpamStatus =~ m{\b(?:DKIM_VALID_AU|DMARC_PASS)\b}i
        && $SpamStatus =~ m{\bSPF_PASS\b}i
        && $ReturnPath =~ m{\@${DomainQuoted}>?\s*\z}i;
    my $AuthenticatedByAlignedMailbox =
           $ReturnPath =~ m{\A\s*<?\Q$ForwarderEmail\E>?\s*\z}i
        && $SpamStatus =~ m{\A\s*No\b}i;

    return 1 if !$AuthenticatedByResults
        && !$AuthenticatedByMailbox
        && !$AuthenticatedByAlignedMailbox;

    my $MatchedData = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail')->CustomerUserDataGetByEmail(
        Email => $CustomerEmail,
    );
    return 1 if !$MatchedData || ( $MatchedData->{UserCustomerID} // '' ) ne $CustomerNo;

    $GetParam->{Subject}                = $CleanSubject;
    $GetParam->{From}                   = $MatchedData->{UserFullname}
        ? "$MatchedData->{UserFullname} <$CustomerEmail>"
        : $CustomerEmail;
    $GetParam->{'X-OTOBO-CustomerUser'} = $MatchedData->{UserLogin};
    $GetParam->{'X-OTOBO-CustomerNo'}   = $CustomerNo;

    $Self->{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Notice',
        Key           => __PACKAGE__,
        Value         => "Authorized customer forward accepted from $ForwarderEmail for $MatchedData->{UserLogin}.",
    );

    return 1;
}

1;
