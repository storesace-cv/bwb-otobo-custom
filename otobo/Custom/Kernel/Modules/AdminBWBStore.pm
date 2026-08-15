package Kernel::Modules::AdminBWBStore;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless { %Param }, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StoreObject  = $Kernel::OM->Get('Kernel::System::BWBStore');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Nav          = $ParamObject->GetParam( Param => 'Nav' ) || 'Agent';

    $StoreObject->HeadquartersEnsureAll( UserID => $Self->{UserID} );

    if ( $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Change' ) {
        my %Data;
        if ( $Self->{Subaction} eq 'Change' ) {
            my $StoreID = $ParamObject->GetParam( Param => 'StoreID' );
            %Data = $StoreObject->StoreGet( StoreID => $StoreID );
            if ( !%Data || !$AccessObject->CustomerAccessCheck( UserID => $Self->{UserID}, CustomerID => $Data{CustomerID} ) ) {
                return $LayoutObject->FatalError( Message => 'Não tem autorização para aceder a esta loja.' );
            }
        }
        return $Self->_Edit( Nav => $Nav, %Data );
    }

    if ( $Self->{Subaction} eq 'AddAction' || $Self->{Subaction} eq 'ChangeAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my %Data;
        for my $Name (qw(StoreID CustomerID StoreNumber StoreName StoreStreet ValidID)) {
            $Data{$Name} = $ParamObject->GetParam( Param => $Name );
        }
        if ( !$AccessObject->CustomerAccessCheck( UserID => $Self->{UserID}, CustomerID => $Data{CustomerID} ) ) {
            return $LayoutObject->FatalError( Message => 'Não tem autorização para alterar lojas deste cliente.' );
        }
        $Data{StoreNumber} =~ s/^\s+|\s+$//g if defined $Data{StoreNumber};
        $Data{StoreName}   =~ s/^\s+|\s+$//g if defined $Data{StoreName};

        my %Errors;
        for my $Required (qw(CustomerID StoreNumber StoreName ValidID)) {
            $Errors{"${Required}Invalid"} = 'ServerError' if !defined $Data{$Required} || $Data{$Required} eq '';
        }

        if ( !%Errors ) {
            my $Success;
            if ( $Self->{Subaction} eq 'AddAction' ) {
                $Success = $StoreObject->StoreAdd( %Data, UserID => $Self->{UserID} );
            }
            else {
                $Success = $StoreObject->StoreUpdate( %Data, UserID => $Self->{UserID} );
            }

            if ($Success) {
                return $LayoutObject->Redirect(
                    OP => "Action=$Self->{Action};Nav=$Nav;Notification=Saved",
                );
            }
            $Errors{StoreNumberInvalid} = 'ServerError';
            $Errors{SaveError} = 1;
        }

        return $Self->_Edit( Nav => $Nav, %Data, %Errors );
    }

    my $Search         = $ParamObject->GetParam( Param => 'Search' ) || '';
    my $IncludeInvalid = $ParamObject->GetParam( Param => 'IncludeInvalid' ) || 0;
    my $Notification   = $ParamObject->GetParam( Param => 'Notification' ) || '';
    my $Stores         = $StoreObject->StoreList(
        Search         => $Search,
        IncludeInvalid => $IncludeInvalid,
    );
    if ( my $Allowed = $AccessObject->CustomerIDsGet( UserID => $Self->{UserID} ) ) {
        my %Allowed = map { $_ => 1 } @{$Allowed};
        $Stores = [ grep { $Allowed{ $_->{CustomerID} } } @{$Stores} ];
    }

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar( Type => 'Customers' );
    $Output .= $LayoutObject->Notify( Info => 'Loja guardada com sucesso.' ) if $Notification eq 'Saved';

    for my $Store ( @{$Stores} ) {
        $LayoutObject->Block( Name => 'StoreRow', Data => { %{$Store}, Nav => $Nav } );
    }
    $LayoutObject->Block( Name => 'NoStores' ) if !@{$Stores};

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminBWBStore',
        Data         => {
            View           => 'Overview',
            Nav            => $Nav,
            Search         => $Search,
            IncludeInvalid => $IncludeInvalid,
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _Edit {
    my ( $Self, %Data ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my %Companies = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList( Valid => 0 );
    if ( my $Allowed = $Kernel::OM->Get('Kernel::System::BWBAccess')->CustomerIDsGet( UserID => $Self->{UserID} ) ) {
        my %Allowed = map { $_ => 1 } @{$Allowed};
        delete $Companies{$_} for grep { !$Allowed{$_} } keys %Companies;
    }
    my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    $Data{CustomerOption} = $LayoutObject->BuildSelection(
        Data         => \%Companies,
        Name         => 'CustomerID',
        SelectedID   => $Data{CustomerID} || '',
        PossibleNone => 1,
        Class        => 'Modernize W50pc Validate_Required',
    );
    $Data{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Data{ValidID} || 1,
        Class      => 'Modernize W50pc Validate_Required',
    );
    $Data{Mode} = $Data{StoreID} ? 'Change' : 'Add';
    $Data{View} = 'Edit';

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar( Type => 'Customers' );
    $Output .= $LayoutObject->Notify( Priority => 'Error', Info => 'Não foi possível guardar a loja. Verifique os campos e se o número já existe neste cliente.' ) if $Data{SaveError};
    $Output .= $LayoutObject->Output( TemplateFile => 'AdminBWBStore', Data => \%Data );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
