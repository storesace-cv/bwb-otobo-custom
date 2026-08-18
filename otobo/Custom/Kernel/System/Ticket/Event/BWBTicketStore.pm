package Kernel::System::Ticket::Event::BWBTicketStore;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBTicketStore',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my $TicketID = $Param{Data}->{TicketID} || 0;
    return 1 if !$TicketID;

    $Kernel::OM->Get('Kernel::System::BWBTicketStore')->EnsureFromCustomerUser(
        TicketID    => $TicketID,
        UserID      => $Param{UserID} || 1,
        OnlyIfEmpty => 1,
    );
    return 1;
}

1;
