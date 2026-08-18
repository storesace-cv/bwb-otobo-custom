package Kernel::Modules::AgentBWBTicketStore;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBTicketStore',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $StoreObject  = $Kernel::OM->Get('Kernel::System::BWBTicketStore');
    my $TicketID     = $ParamObject->GetParam( Param => 'TicketID' ) || 0;
    my $Dialog       = $ParamObject->GetParam( Param => 'Dialog' )   || 0;
    my $Subaction    = $Self->{Subaction}
        || $ParamObject->GetParam( Param => 'Subaction' )
        || '';

    return $Self->_Error( $LayoutObject, $Dialog, 'Ticket inválido ou sem permissão.' )
        if !$TicketID || !$AccessObject->TicketAccessCheck(
            UserID   => $Self->{UserID},
            TicketID => $TicketID,
        );

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        Silent        => 1,
    );
    return $Self->_Error( $LayoutObject, $Dialog, 'Este ticket não tem cliente associado.' )
        if !%Ticket || !$Ticket{CustomerID};

    if ( $Subaction eq 'Set' ) {
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Verificação de segurança inválida.' },
        ) if !$LayoutObject->ChallengeTokenCheck();

        my $StoreID = $ParamObject->GetParam( Param => 'StoreID' ) || 0;
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Selecione a loja.' },
        ) if !$StoreID;

        my $Allowed = 0;
        for my $Store ( @{ $StoreObject->StoresForTicket( TicketID => $TicketID, UserID => $Self->{UserID} ) } ) {
            if ( int( $Store->{StoreID} ) == int($StoreID) ) {
                $Allowed = 1;
                last;
            }
        }
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Sem permissão para esta loja.' },
        ) if !$Allowed;

        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Não foi possível gravar a loja.' },
        ) if !$StoreObject->Set(
            TicketID => $TicketID,
            StoreID  => $StoreID,
            UserID   => $Self->{UserID},
            History  => 1,
        );

        return $LayoutObject->JSONReply(
            Data => {
                Success  => 1,
                Redirect => "Action=AgentTicketZoom;TicketID=$TicketID",
            },
        );
    }

    my $Current = $StoreObject->Get( TicketID => $TicketID ) || {};
    my $HTML    = $LayoutObject->Output(
        TemplateFile => 'AgentBWBTicketStore',
        Data         => {
            TicketID       => $TicketID,
            ChallengeToken => $LayoutObject->{UserChallengeToken} || '',
            CurrentLabel   => $Current->{Label} || '',
            CurrentStoreID => $Current->{StoreID} || 0,
            Stores         => $StoreObject->StoresForTicket(
                TicketID => $TicketID,
                UserID   => $Self->{UserID},
            ),
        },
    );

    return $HTML if $Dialog;

    return $LayoutObject->Header( Type => 'Small' )
        . $HTML
        . $LayoutObject->Footer( Type => 'Small' );
}

sub _Error {
    my ( $Self, $LayoutObject, $Dialog, $Message ) = @_;
    if ($Dialog) {
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => $Message },
        );
    }
    return $LayoutObject->ErrorScreen( Message => $Message );
}

1;
