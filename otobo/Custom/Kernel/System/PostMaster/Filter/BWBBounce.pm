package Kernel::System::PostMaster::Filter::BWBBounce;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBBounce',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = bless {}, $Type;
    $Self->{ParserObject}           = $Param{ParserObject}           || die 'Got no ParserObject!';
    $Self->{CommunicationLogObject} = $Param{CommunicationLogObject} || die 'Got no CommunicationLogObject!';
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return 1 if !$Param{GetParam};

    my $Bounce = $Kernel::OM->Get('Kernel::System::BWBBounce');
    return 1 if !$Bounce->IsBounce( GetParam => $Param{GetParam} );

    $Bounce->ApplyFollowUpHeaders( GetParam => $Param{GetParam} );
    $Self->{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Notice',
        Key           => __PACKAGE__,
        Value         => 'DSN: follow-up without reopening, hidden from customer, no auto-reply.',
    );
    return 1;
}

1;
