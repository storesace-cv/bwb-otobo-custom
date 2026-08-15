package Kernel::Modules::AgentBWBStoreLookup;

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
    my $CustomerID   = $ParamObject->GetParam( Param => 'CustomerID' ) || '';
    my $StoreObject  = $Kernel::OM->Get('Kernel::System::BWBStore');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');

    my @Result;
    my $HeadquartersID;
    my $CustomerCompanyName = '';
    if ($CustomerID) {
        if ( !$AccessObject->CustomerAccessCheck(
            UserID => $Self->{UserID}, CustomerID => $CustomerID,
        ) ) {
            return $LayoutObject->Attachment(
                ContentType => 'application/json',
                Content     => '{"Success":0,"Error":"Sem autorização para este cliente."}',
                Type        => 'inline', NoCache => 1,
            );
        }
        my %Company = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );
        $CustomerCompanyName = $Company{CustomerCompanyName} || '';
        $HeadquartersID = $StoreObject->HeadquartersEnsure(
            CustomerID => $CustomerID,
            UserID     => $Self->{UserID},
        );
        my $Stores = $StoreObject->StoreList(
            CustomerID     => $CustomerID,
            IncludeInvalid => 0,
        );
        @Result = map {
            {
                ID    => 0 + $_->{StoreID},
                Label => $_->{StoreNumber} . ' - ' . $_->{StoreName},
            }
        } @{$Stores};
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => {
            Success        => 1,
            CustomerCompanyName => $CustomerCompanyName,
            HeadquartersID => $HeadquartersID ? 0 + $HeadquartersID : undef,
            Stores         => \@Result,
        },
    );
    return $LayoutObject->Attachment(
        ContentType => 'application/json',
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
