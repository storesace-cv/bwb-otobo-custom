package Kernel::System::PostMaster::Filter::BWBCustomerUserEmail;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::BWBCustomerUserEmail',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = bless {}, $Type;
    $Self->{ParserObject} = $Param{ParserObject} || die 'Got no ParserObject!';
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    return 1 if !$Param{GetParam};
    my $GetParam = $Param{GetParam};
    return 1 if $GetParam->{'X-OTOBO-CustomerUser'};

    my @Addresses = $Self->{ParserObject}->SplitAddressLine( Line => $GetParam->{From} // '' );
    my $Email = '';
    for my $Address (@Addresses) {
        $Email = lc( $Self->{ParserObject}->GetEmailAddress( Email => $Address ) // '' ) || $Email;
    }
    return 1 if !$Email;

    my $Data = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail')->CustomerUserDataGetByEmail( Email => $Email );
    return 1 if !$Data;
    if ( $Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Ticket')->TicketCustomerSet(
            TicketID => $Param{TicketID},
            UserID   => 1,
            No       => $Data->{UserCustomerID},
            User     => $Data->{UserLogin},
        );
        return 1;
    }

    $GetParam->{'X-OTOBO-CustomerUser'} = $Data->{UserLogin};
    $GetParam->{'X-OTOBO-CustomerNo'}   = $Data->{UserCustomerID};
    return 1;
}

1;
