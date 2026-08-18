package Kernel::Modules::BWBTicketIntakeAgent;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub Run {
    my ( $Self, %Param ) = @_;
    my $Origin       = $Param{Origin}       || return;
    my $ScreenTitle  = $Param{ScreenTitle}  || '';
    my $TemplateFile = $Param{TemplateFile} || '';
    my $SubmitLabel  = $Param{SubmitLabel}  || 'Criar';

    my $Layout  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Intake  = $Kernel::OM->Get('Kernel::System::BWBTicketIntake');
    my $Subaction = $Self->{Subaction} || $Request->GetParam( Param => 'Subaction' ) || '';

    if ( $Subaction eq 'CustomerUsers' ) {
        my $CustomerID = $Request->GetParam( Param => 'CustomerID' ) || '';
        if ( !$CustomerID ) {
            return $Layout->JSONReply(
                Data => { Success => 0, Error => 'Selecione um cliente.' },
            );
        }
        my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
        if ( !$Access->CustomerAccessCheck(
            UserID     => $Self->{UserID},
            CustomerID => $CustomerID,
        ) )
        {
            return $Layout->JSONReply(
                Data => { Success => 0, Error => 'Sem permissão para este cliente.' },
            );
        }
        my $Users = $Intake->CustomerUsersForCustomer(
            UserID     => $Self->{UserID},
            CustomerID => $CustomerID,
        );
        return $Layout->JSONReply(
            Data => { Success => 1, Users => $Users },
        );
    }

    if ( $Subaction eq 'StoreNew' ) {
        $Layout->ChallengeTokenCheck();
        return _StoreNew(
            $Self,
            Layout       => $Layout,
            Request      => $Request,
            Intake       => $Intake,
            Origin       => $Origin,
            TemplateFile => $TemplateFile,
            ScreenTitle  => $ScreenTitle,
            SubmitLabel  => $SubmitLabel,
        );
    }

    if ( $Subaction eq 'Created' ) {
        my $TicketID = $Request->GetParam( Param => 'TicketID' ) || 0;
        return $Layout->Redirect( OP => 'Action=AgentTicketZoom;TicketID=' . $TicketID )
            if $TicketID;
        return $Layout->Redirect( OP => 'Action=AgentDashboard' );
    }

    return _ShowForm(
        $Self,
        Layout       => $Layout,
        Request      => $Request,
        Intake       => $Intake,
        Origin       => $Origin,
        TemplateFile => $TemplateFile,
        ScreenTitle  => $ScreenTitle,
        SubmitLabel  => $SubmitLabel,
        Error        => $Request->GetParam( Param => 'Error' ) || '',
    );
}

sub _FormData {
    my ( $Self, %Param ) = @_;
    my $Intake = $Param{Intake};
    my $Request = $Param{Request};

    my $PreCustomerUser = $Request->GetParam( Param => 'CustomerUser' )
        || $Request->GetParam( Param => 'PreSelectedCustomerUser' )
        || '';

    my $SelectedCustomerID = $Request->GetParam( Param => 'CustomerID' ) || '';
    my $SelectedCustomerUser = $Request->GetParam( Param => 'SelectedCustomerUser' ) || $PreCustomerUser;

    if ( $PreCustomerUser && !$SelectedCustomerID ) {
        my %CU = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $PreCustomerUser,
        );
        if (%CU) {
            $SelectedCustomerID   = $CU{UserCustomerID} || $CU{CustomerID} || '';
            $SelectedCustomerUser = $PreCustomerUser;
        }
    }

    my $DefaultQueueID = $Intake->DefaultQueueID( UserID => $Self->{UserID} );
    my $QueueName      = '';
    if ($DefaultQueueID) {
        $QueueName = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            QueueID => $DefaultQueueID,
        ) || '';
    }

    return {
        FormAction           => $Self->{Action},
        Customers            => $Intake->CustomersForAgent( UserID => $Self->{UserID} ),
        CustomerUsers        => $Intake->CustomerUsersForAgent( UserID => $Self->{UserID} ),
        Priorities           => $Intake->PrioritiesForForm(),
        QueueID              => $DefaultQueueID,
        QueueName            => $QueueName,
        SelectedCustomerID   => $SelectedCustomerID,
        SelectedCustomerUser => $SelectedCustomerUser,
        Origin               => $Param{Origin},
        ScreenTitle          => $Param{ScreenTitle},
        SubmitLabel          => $Param{SubmitLabel},
        Error                => $Param{Error} || '',
    };
}

sub _ShowForm {
    my ( $Self, %Param ) = @_;
    my $Layout = $Param{Layout};
    my $Data   = _FormData(
        $Self,
        Intake       => $Param{Intake},
        Request      => $Param{Request},
        Origin       => $Param{Origin},
        ScreenTitle  => $Param{ScreenTitle},
        SubmitLabel  => $Param{SubmitLabel},
        Error        => $Param{Error},
    );

    my $Output = $Layout->Header( Title => $Param{ScreenTitle} );
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentBWBTicketIntake',
        Data         => $Data,
    );
    $Output .= $Layout->Footer();
    return $Output;
}

sub _StoreNew {
    my ( $Self, %Param ) = @_;
    my $Layout  = $Param{Layout};
    my $Request = $Param{Request};
    my $Intake  = $Param{Intake};

    my $CustomerID   = $Request->GetParam( Param => 'CustomerID' )   || '';
    my $CustomerUser = $Request->GetParam( Param => 'CustomerUser' ) || '';
    my $QueueID      = $Intake->DefaultQueueID( UserID => $Self->{UserID} ) || '';
    my $PriorityID   = $Request->GetParam( Param => 'PriorityID' )   || '';
    my $Title        = $Request->GetParam( Param => 'Subject' )      || '';
    my $Body         = $Request->GetParam( Param => 'Body' )         || '';

    my $Fail = sub {
        my ($Msg) = @_;
        my $Data = _FormData(
            $Self,
            Intake      => $Intake,
            Request     => $Request,
            Origin      => $Param{Origin},
            ScreenTitle => $Param{ScreenTitle},
            SubmitLabel => $Param{SubmitLabel},
            Error       => $Msg,
        );
        $Data->{FormCustomerID}   = $CustomerID;
        $Data->{FormCustomerUser} = $CustomerUser;
        $Data->{FormPriorityID}   = $PriorityID;
        $Data->{FormSubject}      = $Title;
        $Data->{FormBody}         = $Body;

        my $Output = $Layout->Header( Title => $Param{ScreenTitle} );
        $Output .= $Layout->NavigationBar();
        $Output .= $Layout->Output(
            TemplateFile => 'AgentBWBTicketIntake',
            Data         => $Data,
        );
        $Output .= $Layout->Footer();
        return $Output;
    };

    return $Fail->('Indique o cliente.')               if !$CustomerID;
    return $Fail->('Indique o utilizador de cliente.') if !$CustomerUser;
    return $Fail->('Fila por defeito indisponível.')   if !$QueueID || $QueueID !~ m{\A\d+\z};
    return $Fail->('Indique a prioridade.')            if !$PriorityID || $PriorityID !~ m{\A\d+\z};
    return $Fail->('Indique o assunto.')               if $Title !~ m{\S};
    return $Fail->('Descreva o pedido.')               if $Body !~ m{\S};

    my $TicketID = $Intake->Create(
        UserID           => $Self->{UserID},
        CustomerID       => $CustomerID,
        CustomerUser     => $CustomerUser,
        QueueID          => $QueueID,
        PriorityID       => $PriorityID,
        Title            => $Title,
        Body             => $Body,
        Origin           => $Param{Origin},
        SendDeclaration  => 1,
        OwnerID          => 1,
        Lock             => 'unlock',
    );
    return $Fail->('Não foi possível criar o ticket.') if !$TicketID;

    return $Layout->Redirect(
        OP => 'Action=' . $Self->{Action} . ';Subaction=Created;TicketID=' . $TicketID,
    );
}

1;
