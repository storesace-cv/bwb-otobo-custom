package Kernel::System::PostMaster::Filter::ZSAKnownCustomer;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
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
    return if !$Param{GetParam};

    # Follow-ups must remain attached to the existing ticket and queue.
    return 1 if $Param{TicketID};

    my $GetParam = $Param{GetParam};
    my $Recipients = join ' ', map { $GetParam->{$_} // '' } qw(To Cc Delivered-To X-Original-To);
    return 1 if $Recipients !~ m{\bassistencia\@zsa-softwares\.com\b}i;

    my @FromAddresses = $Self->{ParserObject}->SplitAddressLine(
        Line => $GetParam->{From} // '',
    );
    my $SenderEmail = '';
    for my $Address (@FromAddresses) {
        my $Email = lc( $Self->{ParserObject}->GetEmailAddress( Email => $Address ) // '' );
        $SenderEmail = $Email if $Email;
    }

    my $KnownCustomerUser = 0;
    if ($SenderEmail) {
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
        my %Candidates = $CustomerUserObject->CustomerSearch(
            PostMasterSearch => $SenderEmail,
            Valid            => 1,
        );
        CANDIDATE:
        for my $Login ( keys %Candidates ) {
            my %Data = $CustomerUserObject->CustomerUserDataGet( User => $Login );
            next CANDIDATE if !%Data;
            if ( lc( $Data{UserEmail} // '' ) eq $SenderEmail ) {
                $KnownCustomerUser = 1;
                last CANDIDATE;
            }
        }
    }

    $GetParam->{'X-OTOBO-Queue'} = $KnownCustomerUser ? 'zsangola-in' : 'zs-postmaster';

    $Self->{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Notice',
        Key           => __PACKAGE__,
        Value         => $KnownCustomerUser
            ? "Known ZSA customer user $SenderEmail routed to zsangola-in."
            : "Unknown ZSA sender $SenderEmail routed to zs-postmaster.",
    );

    return 1;
}

1;
