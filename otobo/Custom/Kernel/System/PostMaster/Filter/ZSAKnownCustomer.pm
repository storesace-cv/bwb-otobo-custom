package Kernel::System::PostMaster::Filter::ZSAKnownCustomer;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBBounce',
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
    return if !$Param{GetParam};

    # Follow-ups must remain attached to the existing ticket and queue.
    return 1 if $Param{TicketID};

    my $GetParam = $Param{GetParam};
    # A DSN is not a customer. Leave routing to BounceEmail / BWBBounce follow-up.
    if ( $Kernel::OM->Get('Kernel::System::BWBBounce')->IsBounce( GetParam => $GetParam ) ) {
        $Self->{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Notice',
            Key           => __PACKAGE__,
            Value         => 'DSN detected; queue override skipped.',
        );
        return 1;
    }
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

    my $KnownCustomerUser = $GetParam->{'X-OTOBO-CustomerUser'} ? 1 : 0;
    if ($SenderEmail) {
        my $Data = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail')->CustomerUserDataGetByEmail(
            Email => $SenderEmail,
        );
        if ($Data) {
            $KnownCustomerUser = 1;
            $GetParam->{'X-OTOBO-CustomerUser'} ||= $Data->{UserLogin};
            $GetParam->{'X-OTOBO-CustomerNo'}   ||= $Data->{UserCustomerID};
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
