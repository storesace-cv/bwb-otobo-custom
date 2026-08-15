package Kernel::Modules::PublicBWBInvite;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless { %Param }, $Type;
}

sub Run {
    my ($Self) = @_;

    my $RequestObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Token         = $RequestObject->GetParam( Param => 'Token' ) || '';
    my %Data          = ( Token => $Token );

    if ( $Self->{Subaction} eq 'Set' ) {
        $LayoutObject->ChallengeTokenCheck();
        my $Password = $RequestObject->GetParam( Param => 'Password' ) || '';
        my $Confirm  = $RequestObject->GetParam( Param => 'Confirm' )  || '';

        if ( $Password ne $Confirm ) {
            $Data{Error} = 'As palavras-passe não coincidem.';
        }
        elsif (
            !$Kernel::OM->Get('Kernel::System::BWBInvite')->Consume(
                Token    => $Token,
                Password => $Password,
            )
            )
        {
            $Data{Error} = 'A ligação expirou ou a palavra-passe não cumpre os requisitos.';
        }
        else {
            $Data{Success} = 1;
        }
    }
    else {
        $Data{Invalid} = 1
            if !$Kernel::OM->Get('Kernel::System::BWBInvite')->Validate( Token => $Token );
    }

    return $LayoutObject->Output(
        TemplateFile => 'PublicBWBInvite',
        Data         => \%Data,
    );
}

1;
