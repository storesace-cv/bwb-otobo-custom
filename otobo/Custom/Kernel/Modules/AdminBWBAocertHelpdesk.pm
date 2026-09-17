package Kernel::Modules::AdminBWBAocertHelpdesk;

use strict;
use warnings;
use utf8;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ($Self) = @_;
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Ficha        = $Kernel::OM->Get('Kernel::System::BWBAocertHelpdesk');
    my $Subaction    = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my %Data;

    if ( $Subaction eq 'Save' ) {
        $LayoutObject->ChallengeTokenCheck();
        my @Phones = $ParamObject->GetArray( Param => 'Phone' );
        if ( !@Phones ) {
            my $One = $ParamObject->GetParam( Param => 'Phone' );
            @Phones = ($One) if defined $One && $One ne '';
        }
        my $Ok     = $Ficha->Set(
            UserID    => $Self->{UserID},
            Operation => scalar $ParamObject->GetParam( Param => 'Operation' ),
            Email     => scalar $ParamObject->GetParam( Param => 'Email' ),
            Portal    => scalar $ParamObject->GetParam( Param => 'Portal' ),
            Phones    => \@Phones,
        );
        $Data{Message} = $Ok
            ? 'Ficha Heldesk AOcert gravada.'
            : 'Não foi possível gravar. Email, portal https e pelo menos um telefone são obrigatórios, e só pode editar a ficha da sua operação.';
    }

    $Data{Items} = $Ficha->ListForUser( UserID => $Self->{UserID} );
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output( TemplateFile => 'AdminBWBAocertHelpdesk', Data => \%Data );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
