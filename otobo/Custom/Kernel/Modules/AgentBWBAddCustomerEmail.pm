package Kernel::Modules::AgentBWBAddCustomerEmail;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBConvertCustomer',
    'Kernel::System::BWBCustomerUserEmail',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
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
    my $TicketID     = $ParamObject->GetParam( Param => 'TicketID' ) || 0;
    my $Dialog       = $ParamObject->GetParam( Param => 'Dialog' )   || 0;
    my $Subaction    = $Self->{Subaction} || '';

    return $Self->_Error( $LayoutObject, $Dialog, 'Ticket inválido ou sem permissão.' )
        if !$TicketID || !$AccessObject->TicketAccessCheck(
            UserID   => $Self->{UserID},
            TicketID => $TicketID,
        );

    my $Sender = $Kernel::OM->Get('Kernel::System::BWBConvertCustomer')->SenderGet(
        TicketID => $TicketID,
    );
    return $Self->_Error( $LayoutObject, $Dialog, 'Não foi possível determinar o endereço do remetente.' )
        if !$Sender->{Email};

    my $EmailObject = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail');
    my $Existing    = $EmailObject->CustomerUserDataGetByEmail( Email => $Sender->{Email} );
    return $Self->_Error( $LayoutObject, $Dialog, 'Este endereço já está associado a um utilizador de cliente.' )
        if $Existing;

    if ( $Subaction eq 'CustomerUsers' ) {
        my $CustomerID = $ParamObject->GetParam( Param => 'CustomerID' ) || '';
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Selecione um cliente.' },
        ) if !$CustomerID;

        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Sem permissão para este cliente.' },
        ) if !$AccessObject->CustomerAccessCheck(
            UserID     => $Self->{UserID},
            CustomerID => $CustomerID,
        );

        return $LayoutObject->JSONReply(
            Data => {
                Success => 1,
                Users   => $Self->_UsersForCustomer(
                    CustomerID => $CustomerID,
                    UserID     => $Self->{UserID},
                ),
            },
        );
    }

    if ( $Subaction eq 'Add' ) {
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Verificação de segurança inválida.' },
        ) if !$LayoutObject->ChallengeTokenCheck();

        my $CustomerID        = $ParamObject->GetParam( Param => 'CustomerID' )        || '';
        my $CustomerUserLogin = $ParamObject->GetParam( Param => 'CustomerUserLogin' ) || '';

        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Selecione o cliente e o utilizador de cliente.' },
        ) if !$CustomerID || !$CustomerUserLogin;

        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Sem permissão para este cliente.' },
        ) if !$AccessObject->CustomerAccessCheck(
            UserID     => $Self->{UserID},
            CustomerID => $CustomerID,
        );

        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Sem permissão para este utilizador de cliente.' },
        ) if !$AccessObject->CustomerUserAccessCheck(
            UserID            => $Self->{UserID},
            CustomerUserLogin => $CustomerUserLogin,
        );

        my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );
        return $LayoutObject->JSONReply(
            Data => { Success => 0, Error => 'Utilizador de cliente inválido.' },
        ) if !%CustomerUser || ( $CustomerUser{UserCustomerID} // '' ) ne $CustomerID;

        if (
            !$EmailObject->EmailAdd(
                CustomerUserLogin => $CustomerUserLogin,
                Email             => $Sender->{Email},
                UserID            => $Self->{UserID},
            )
            )
        {
            return $LayoutObject->JSONReply(
                Data => {
                    Success => 0,
                    Error   => $EmailObject->LastError() || 'Não foi possível associar o endereço.',
                },
            );
        }

        if (
            !$Kernel::OM->Get('Kernel::System::Ticket')->TicketCustomerSet(
                TicketID => $TicketID,
                UserID   => $Self->{UserID},
                No       => $CustomerUser{UserCustomerID},
                User     => $CustomerUserLogin,
            )
            )
        {
            return $LayoutObject->JSONReply(
                Data => {
                    Success => 0,
                    Error   => 'O e-mail foi associado, mas não foi possível atualizar o ticket.',
                },
            );
        }

        return $LayoutObject->JSONReply(
            Data => {
                Success  => 1,
                Redirect => "Action=AgentTicketZoom;TicketID=$TicketID",
            },
        );
    }

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'AgentBWBAddCustomerEmail',
        Data         => {
            TicketID       => $TicketID,
            SenderEmail    => $Sender->{Email},
            ChallengeToken => $LayoutObject->{UserChallengeToken} || '',
            Customers      => $Self->_CustomersForAgent( UserID => $Self->{UserID} ),
        },
    );

    # Fragmento para o modal — sem Header/Footer de página.
    return $HTML if $Dialog;

    return $LayoutObject->Header( Type => 'Small' )
        . $HTML
        . $LayoutObject->Footer( Type => 'Small' );
}

sub _CustomersForAgent {
    my ( $Self, %Param ) = @_;

    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $AllowedIDs   = $AccessObject->CustomerIDsGet( UserID => $Param{UserID} );
    my %Allowed      = map { $_ => 1 } @{ $AllowedIDs || [] };
    my $Restrict     = defined $AllowedIDs ? 1 : 0;

    my %Companies = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
        Valid => 1,
    );

    my @Customers;
    for my $CustomerID ( sort { lc( $Companies{$a} // '' ) cmp lc( $Companies{$b} // '' ) } keys %Companies ) {
        next if $Restrict && !$Allowed{$CustomerID};
        next if !$AccessObject->CustomerAccessCheck(
            UserID     => $Param{UserID},
            CustomerID => $CustomerID,
        );
        push @Customers, {
            ID    => $CustomerID,
            Label => $Companies{$CustomerID} || $CustomerID,
        };
    }
    return \@Customers;
}

sub _UsersForCustomer {
    my ( $Self, %Param ) = @_;

    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL =>
            'SELECT login, first_name, last_name, email FROM customer_user WHERE valid_id = 1 AND customer_id = ? ORDER BY last_name, first_name, login',
        Bind => [ \$Param{CustomerID} ],
    );

    my @Users;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next if !$AccessObject->CustomerUserAccessCheck(
            UserID            => $Param{UserID},
            CustomerUserLogin => $Row[0],
        );
        my $Name = join ' ', grep {$_} @Row[ 1, 2 ];
        push @Users, {
            Login => $Row[0],
            Label => ( $Name || $Row[0] ) . ( $Row[3] ? " <$Row[3]>" : '' ),
        };
    }
    return \@Users;
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
