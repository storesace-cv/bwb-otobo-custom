package Kernel::Modules::AgentBWBConvertCustomer;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;
sub new { my ( $Type, %Param ) = @_; return bless { %Param }, $Type; }

sub Run {
    my ($Self) = @_;
    my $Layout = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Service = $Kernel::OM->Get('Kernel::System::BWBConvertCustomer');
    my $TicketID = $Self->{TicketID} || $Request->GetParam( Param => 'TicketID' ) || 0;
    return $Layout->NoPermission( WithHeader => 'yes' ) if !$Service->Allowed( TicketID => $TicketID, UserID => $Self->{UserID} );

    my $Sender = $Service->SenderGet( TicketID => $TicketID ) || {};
    my $Name = $Sender->{Name} || '';
    my @NameParts = grep { length } split /\s+/, $Name;
    my $Firstname = shift(@NameParts) || '';
    my $Lastname = join ' ', @NameParts;
    my %Data = (
        TicketID => $TicketID, UserEmail => $Sender->{Email} || '', Firstname => $Firstname, Lastname => $Lastname,
        CustomerID => $Service->CustomerIDSuggest(), CustomerName => '', CustomerStreet => '', CustomerPhone => '', StoreStreet => '',
    );
    $Data{UserLogin} = $Service->LoginSuggest( Firstname => $Firstname, Lastname => $Lastname );

    if ( $Self->{Subaction} eq 'Convert' ) {
        $Layout->ChallengeTokenCheck();
        for my $Key (qw(CustomerID CustomerName CustomerStreet CustomerPhone StoreStreet Firstname Lastname UserLogin UserEmail)) {
            $Data{$Key} = $Request->GetParam( Param => $Key ) // '';
        }
        if ( ( $Request->GetParam( Param => 'Confirmed' ) || '' ) eq '1' ) {
            my $Result = $Service->Convert( %Data, TicketID => $TicketID, UserID => $Self->{UserID} );
            if ( $Result->{Success} ) {
                return $Layout->Redirect( OP => 'Action=AgentTicketZoom;TicketID=' . $TicketID . ';BWBConverted=1' );
            }
            $Data{Error} = $Result->{Error};
        }
    }
    my $Matches = $Service->MatchingTicketIDsGet( Email => $Data{UserEmail} );
    $Data{TicketCount} = scalar @{$Matches};
    $Data{TicketNumbers} = join ', ', @{$Matches};
    my $Output = $Layout->Header( Type => 'Small', Title => 'Converter remetente em cliente' );
    $Output .= $Layout->Output( TemplateFile => 'AgentBWBConvertCustomer', Data => \%Data );
    $Output .= $Layout->Footer( Type => 'Small' );
    return $Output;
}
1;
