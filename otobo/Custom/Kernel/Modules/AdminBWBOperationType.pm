package Kernel::Modules::AdminBWBOperationType;

use strict;
use warnings;
use utf8;

sub new { my ( $Type, %Param ) = @_; return bless { %Param }, $Type; }

sub Run {
    my ($Self) = @_;
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TypeObject   = $Kernel::OM->Get('Kernel::System::BWBOperationType');
    my $Subaction    = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my %Data;

    if ( $Subaction eq 'Add' ) {
        $LayoutObject->ChallengeTokenCheck();
        my $Name = $ParamObject->GetParam( Param => 'Name' ) || '';
        $Data{Message} = $TypeObject->Add( UserID => $Self->{UserID}, Name => $Name )
            ? 'Tipo de operação criado.' : 'Não foi possível criar o tipo de operação.';
    }
    elsif ( $Subaction eq 'UpdateOwn' ) {
        $LayoutObject->ChallengeTokenCheck();
        $Data{Message} = $TypeObject->OwnUpdate(
            UserID => $Self->{UserID},
            ID      => scalar $ParamObject->GetParam( Param => 'ID' ),
            Name    => scalar( $ParamObject->GetParam( Param => 'Name' ) || '' ),
            ValidID => scalar( $ParamObject->GetParam( Param => 'ValidID' ) || 2 ),
        ) ? 'Tipo de operação atualizado.' : 'Não foi possível atualizar o tipo de operação.';
    }
    elsif ( $Subaction eq 'ToggleGlobal' ) {
        $LayoutObject->ChallengeTokenCheck();
        $Data{Message} = $TypeObject->GlobalHiddenSet(
            UserID => $Self->{UserID},
            ID     => scalar $ParamObject->GetParam( Param => 'ID' ),
            Hidden => scalar( $ParamObject->GetParam( Param => 'Hidden' ) || 0 ),
        ) ? 'Disponibilidade atualizada para a sua equipa.' : 'Não foi possível atualizar a disponibilidade.';
    }

    $Data{Items} = $TypeObject->List( UserID => $Self->{UserID} );
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output( TemplateFile => 'AdminBWBOperationType', Data => \%Data );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
