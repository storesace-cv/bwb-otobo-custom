# --
# Headers X-BWB-* e contexto JSON read-only para Claude Mail MCP.
# --
package Kernel::System::BWBEmailContext;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBTicketStore',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub ResolveTicketID {
    my ( $Self, %Param ) = @_;
    return $Param{TicketID} if $Param{TicketID};
    return if !$Param{ArticleID};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL   => 'SELECT ticket_id FROM article WHERE id = ?',
        Bind  => [ \$Param{ArticleID} ],
        Limit => 1,
    );
    my @Row = $DBObject->FetchrowArray();
    return $Row[0];
}

sub InferSource {
    my ( $Self, %Param ) = @_;
    return $Param{BWBSource} if $Param{BWBSource};

    my $HistoryType = $Param{HistoryType} || '';
    return 'compose' if $HistoryType eq 'SendAnswer';
    return 'notification'
        if $HistoryType =~ /Notification|SendCustomerNotification/i;
    return 'outbound';
}

sub DirectionForSource {
    my ( $Self, $Source ) = @_;
    $Source ||= 'outbound';
    return 'intake-declaration' if $Source eq 'intake';
    return 'notification'      if $Source eq 'notification';
    return 'outbound';
}

sub HeadersForTicket {
    my ( $Self, %Param ) = @_;
    my $TicketID = $Self->ResolveTicketID(%Param);
    return () if !$TicketID;

    my $Context = $Self->ContextForTicket( TicketID => $TicketID );
    return () if !$Context || !$Context->{ok};

    my $Source = $Self->InferSource(%Param);

    return (
        'X-BWB-TicketNumber' => $Context->{ticket_number} // '',
        'X-BWB-TicketID'     => $Context->{ticket_id}     // '',
        'X-BWB-Direction'    => $Self->DirectionForSource($Source),
        'X-BWB-Source'       => $Source,
        'X-BWB-Queue'        => $Context->{queue}           // '',
        'X-BWB-CustomerID'   => $Context->{customer_id}     // '',
        'X-BWB-CustomerUser' => $Context->{customer_user}   // '',
        'X-BWB-State'        => $Context->{state}           // '',
        'X-BWB-Priority'     => $Context->{priority}        // '',
        'X-BWB-Store'        => $Context->{store_label}     // '',
    );
}

sub ContextForTicket {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketID     = $Param{TicketID};
    if ( !$TicketID && $Param{TicketNumber} ) {
        $TicketID = $TicketObject->TicketIDLookup(
            TicketNumber => $Param{TicketNumber},
            UserID       => 1,
        );
    }
    return { ok => 0, error => 'ticket_not_found', status => 404 } if !$TicketID;

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => 1,
        Silent        => 1,
    );
    return { ok => 0, error => 'ticket_not_found', status => 404 } if !%Ticket;

    my $CustomerCompany = '';
    if ( $Ticket{CustomerID} ) {
        my %Company = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $Ticket{CustomerID},
        );
        $CustomerCompany = $Company{CustomerCompanyName} || $Ticket{CustomerID};
    }

    my $CustomerUserName  = '';
    my $CustomerUserEmail = '';
    if ( $Ticket{CustomerUserID} ) {
        my %CU = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
        if (%CU) {
            $CustomerUserName = join(
                ' ',
                grep {$_} ( $CU{UserFirstname}, $CU{UserLastname} )
            ) || $CU{UserFullname} || '';
            $CustomerUserEmail = $CU{UserEmail} || '';
        }
    }

    my $StoreLabel = '';
    my $Store = $Kernel::OM->Get('Kernel::System::BWBTicketStore')->Get(
        TicketID => $TicketID,
    );
    $StoreLabel = $Store->{Label} if $Store && $Store->{Label};

    my $Owner = '';
    if ( $Ticket{OwnerID} ) {
        my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $Ticket{OwnerID},
        );
        $Owner = join( ' ', grep {$_} ( $User{UserFirstname}, $User{UserLastname} ) )
            || $User{UserLogin}
            || '';
    }

    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $URL    = ( $Config->Get('HttpType') || 'https' ) . '://'
        . ( $Config->Get('FQDN') || 'helpdesk.storesace.cv' )
        . '/'
        . ( $Config->Get('ScriptAlias') || 'otobo/' )
        . 'index.pl?Action=AgentTicketZoom;TicketID='
        . $TicketID;

    return {
        ok                  => 1,
        status              => 200,
        ticket_number       => $Ticket{TicketNumber} // '',
        ticket_id           => int($TicketID),
        title               => $Ticket{Title} // '',
        queue               => $Ticket{Queue} // '',
        state               => $Ticket{State} // '',
        priority            => $Ticket{Priority} // '',
        customer_id         => $Ticket{CustomerID} // '',
        customer_company    => $CustomerCompany,
        customer_user       => $Ticket{CustomerUserID} // '',
        customer_user_name  => $CustomerUserName,
        customer_user_email => $CustomerUserEmail,
        store_label         => $StoreLabel,
        owner               => $Owner,
        url_agent           => $URL,
    };
}

sub MergeCustomHeaders {
    my ( $Self, %Param ) = @_;
    my %Send = %{ $Param{Send} || {} };

    my $TicketID = $Self->ResolveTicketID(%Send);
    return %Send if !$TicketID;

    $Send{TicketID} = $TicketID;
    my $Existing = $Send{CustomHeaders};
    $Existing = {} if ref $Existing ne 'HASH';
    return %Send if $Existing->{'X-BWB-TicketNumber'};

    my %Headers = $Self->HeadersForTicket(
        TicketID    => $TicketID,
        BWBSource   => $Send{BWBSource},
        HistoryType => $Send{HistoryType},
    );
    return %Send if !%Headers;

    $Send{CustomHeaders} = { %{$Existing}, %Headers };
    return %Send;
}

1;
