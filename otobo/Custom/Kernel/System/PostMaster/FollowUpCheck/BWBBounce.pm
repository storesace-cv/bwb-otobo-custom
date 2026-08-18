package Kernel::System::PostMaster::FollowUpCheck::BWBBounce;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBBounce',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = bless {}, $Type;
    $Self->{ParserObject}          = $Param{ParserObject}          || die 'Got no ParserObject!';
    $Self->{CommunicationLogObject} = $Param{CommunicationLogObject} || die 'Got no CommunicationLogObject!';
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return if !$Param{GetParam};

    my $Bounce = $Kernel::OM->Get('Kernel::System::BWBBounce');
    return if !$Bounce->IsBounce( GetParam => $Param{GetParam} );

    $Bounce->ApplyFollowUpHeaders( GetParam => $Param{GetParam} );

    my $TicketID = $Bounce->FindTicketID(
        GetParam     => $Param{GetParam},
        ParserObject => $Self->{ParserObject},
    );
    return if !$TicketID;

    $Self->{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Notice',
        Key           => __PACKAGE__,
        Value         => "DSN associada ao ticket $TicketID.",
    );
    return $TicketID;
}

1;
