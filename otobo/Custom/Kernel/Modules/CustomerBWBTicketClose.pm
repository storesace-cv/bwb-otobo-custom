package Kernel::Modules::CustomerBWBTicketClose;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

# Estados em que o cliente pode confirmar e encerrar a ocorrência.
my %CloseableState = (
    'Pendente a aguardar cliente' => 1,
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketID      = $ParamObject->GetParam( Param => 'TicketID' ) || 0;

    if ( !$TicketID ) {
        return $LayoutObject->CustomerErrorScreen(
            Message => 'Ticket inválido.',
            Comment => 'Não foi possível encerrar a ocorrência.',
        );
    }

    my $Access = $TicketObject->TicketCustomerPermission(
        Type     => 'ro',
        TicketID => $TicketID,
        UserID   => $Self->{UserID},
    );
    if ( !$Access ) {
        return $LayoutObject->CustomerNoPermission( WithHeader => 'yes' );
    }

    $LayoutObject->ChallengeTokenCheck();

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => $ConfigObject->Get('CustomerPanelUserID'),
        Silent        => 1,
    );
    if ( !%Ticket ) {
        return $LayoutObject->CustomerErrorScreen(
            Message => 'Ticket não encontrado.',
            Comment => 'Não foi possível encerrar a ocorrência.',
        );
    }

    if ( !$CloseableState{ $Ticket{State} || '' } ) {
        return $LayoutObject->Redirect(
            OP => "Action=CustomerTicketZoom;TicketID=$TicketID",
        );
    }

    my $SystemUserID = $ConfigObject->Get('CustomerPanelUserID');
    my $From         = "\"$Self->{UserFullname}\" <$Self->{UserEmail}>";
    my $Subject      = 'Ocorrência encerrada pelo cliente';
    my $Body
        = 'Confirmei a resolução e encerrei esta ocorrência através do portal de cliente.';

    my $Ok = $TicketObject->StateSet(
        TicketID => $TicketID,
        State    => 'encerrado com êxito',
        UserID   => $SystemUserID,
    );
    if ( !$Ok ) {
        return $LayoutObject->CustomerErrorScreen(
            Message => 'Não foi possível alterar o estado do ticket.',
            Comment => 'Tente novamente ou contacte o helpdesk.',
        );
    }

    $TicketObject->TicketLockSet(
        TicketID => $TicketID,
        Lock     => 'unlock',
        UserID   => $SystemUserID,
    );

    my $ArticleID = $Kernel::OM->Get('Kernel::System::Ticket::Article::Backend::Internal')->ArticleCreate(
        TicketID             => $TicketID,
        IsVisibleForCustomer => 1,
        SenderType           => 'customer',
        From                 => $From,
        Subject              => $Subject,
        Body                 => $Body,
        MimeType             => 'text/plain',
        Charset              => $LayoutObject->{UserCharset} || 'utf-8',
        UserID               => $SystemUserID,
        HistoryType          => 'FollowUp',
        HistoryComment       => '%%Cliente encerrou a ocorrência',
        AutoResponseType     => ( $ConfigObject->Get('AutoResponseForWebTickets') )
        ? 'auto follow up'
        : '',
    );
    if ( !$ArticleID ) {
        return $LayoutObject->CustomerErrorScreen(
            Message => 'O estado foi actualizado, mas o registo da confirmação falhou.',
            Comment => 'Contacte o helpdesk se necessário.',
        );
    }

    return $LayoutObject->Redirect(
        OP => "Action=CustomerTicketZoom;TicketID=$TicketID",
    );
}

1;
