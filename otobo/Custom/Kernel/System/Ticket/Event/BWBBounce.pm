package Kernel::System::Ticket::Event::BWBBounce;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBBounceNotify',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return 1 if ( $Param{Event} || '' ) ne 'ArticleCreate';
    my $TicketID  = $Param{Data}->{TicketID}  || 0;
    my $ArticleID = $Param{Data}->{ArticleID} || 0;
    return 1 if !$TicketID || !$ArticleID;

    $Kernel::OM->Get('Kernel::System::BWBBounceNotify')->Notify(
        TicketID  => $TicketID,
        ArticleID => $ArticleID,
    );
    return 1;
}

1;
