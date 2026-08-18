package Kernel::Output::HTML::FilterElementPost::BWBHideAccountedDuration;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBCustomerCompany',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless $Self, $Type;
    $Self->{Action} = $Param{Action} || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Data};
    return 1 if $Self->{Action} ne 'CustomerTicketZoom';

    my $TicketID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketID' );
    return 1 if !$TicketID;
    return 1 if $Kernel::OM->Get('Kernel::System::BWBCustomerCompany')->ShowAccountedDurationGet(
        TicketID => $TicketID,
    );

    ${ $Param{Data} } =~ s{(<div id="oooContent" class="[^"]*)}{$1 BWBHideAccountedDuration};

    return 1;
}

1;
