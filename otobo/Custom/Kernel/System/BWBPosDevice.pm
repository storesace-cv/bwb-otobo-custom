# --
# Dispositivos POS Helpdesk: sessão de agente, enrol, estados, tickets origem pos.
# --
package Kernel::System::BWBPosDevice;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);

our @ObjectDependencies = (
    'Kernel::System::Auth',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBAocertHelpdesk',
    'Kernel::System::BWBStore',
    'Kernel::System::BWBTicketStore',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
    'Kernel::System::User',
);

use constant SESSION_TTL_SECONDS     => 600;
use constant AUTH_FAIL_WINDOW        => 900;
use constant AUTH_FAIL_MAX           => 8;
use constant TICKET_WINDOW_SECONDS   => 3600;
use constant TICKET_WINDOW_MAX       => 8;
use constant CONTACTS_WINDOW_SECONDS => 3600;
use constant CONTACTS_WINDOW_MAX     => 30;
use constant MAX_TITLE               => 200;
use constant MAX_BODY                => 20_000;
use constant MAX_LOGS_BYTES          => 1_572_864;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub RemoteAddr {
    my ( $Self, %Param ) = @_;
    my $RemoteAddr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR} || '';
    $RemoteAddr =~ s/\s//g;
    if ( $RemoteAddr =~ /,/ ) {
        ($RemoteAddr) = split /,/, $RemoteAddr;
    }
    $RemoteAddr = substr( $RemoteAddr, 0, 64 );
    return $RemoteAddr || '0.0.0.0';
}

sub TokenHash {
    my ( $Self, $Token ) = @_;
    return if !defined $Token || $Token eq '';
    return sha256_hex($Token);
}

sub _RandomToken {
    my ( $Self, $Bytes ) = @_;
    $Bytes ||= 32;
    my $Raw = '';
    if ( open my $Fh, '<', '/dev/urandom' ) {
        read $Fh, $Raw, $Bytes;
        close $Fh;
    }
    if ( length($Raw) < $Bytes ) {
        $Raw = join '', map { chr( int( rand(256) ) ) } ( 1 .. $Bytes );
    }
    return unpack( 'H*', $Raw );
}

sub QueueForCustomerID {
    my ( $Self, $CustomerID ) = @_;
    return 'zsangola-in' if ( $CustomerID || '' ) =~ /^ZSA/i;
    return 'bwb-in';
}

sub AuthAgent {
    my ( $Self, %Param ) = @_;
    my $Login = $Param{User} // $Param{Login} // '';
    my $Pw    = $Param{Password} // $Param{Pw} // '';
    $Login =~ s/^\s+|\s+$//g;
    return { ok => 0, error => 'need_credentials', status => 400 } if !$Login || !length $Pw;

    my $IP = $Self->RemoteAddr();
    if ( $Self->_AuthLocked( RemoteAddr => $IP ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "BWBPosDevice: auth locked IP=$IP",
        );
        return { ok => 0, error => 'too_many_attempts', status => 429 };
    }

    my $AuthLogin = $Kernel::OM->Get('Kernel::System::Auth')->Auth(
        User => $Login,
        Pw   => $Pw,
    );
    if ( !$AuthLogin ) {
        $Self->_AuthFail( RemoteAddr => $IP );
        return { ok => 0, error => 'unauthorized', status => 401 };
    }

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $UserID     = $UserObject->UserLookup( UserLogin => $AuthLogin );
    return { ok => 0, error => 'unauthorized', status => 401 } if !$UserID;

    my %User = $UserObject->GetUserData( UserID => $UserID, Valid => 1 );
    if ( !%User ) {
        $Self->_AuthFail( RemoteAddr => $IP );
        return { ok => 0, error => 'unauthorized', status => 401 };
    }

    $Self->_AuthClear( RemoteAddr => $IP );
    my $Session = $Self->_SessionCreate( UserID => $UserID, RemoteAddr => $IP );
    return {
        ok            => 1,
        status        => 200,
        session_token => $Session,
        user          => $AuthLogin,
        expires_s     => SESSION_TTL_SECONDS(),
    };
}

sub SessionUserID {
    my ( $Self, %Param ) = @_;
    my $Token = $Param{SessionToken} || '';
    return if !$Token;
    my $Hash     = $Self->TokenHash($Token);
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $DBObject->Do( SQL => 'DELETE FROM bwb_pos_session WHERE expires < UTC_TIMESTAMP()' );
    return if !$DBObject->Prepare(
        SQL   => 'SELECT user_id FROM bwb_pos_session WHERE token_hash = ? AND expires >= UTC_TIMESTAMP()',
        Bind  => [ \$Hash ],
        Limit => 1,
    );
    my ($UserID) = $DBObject->FetchrowArray();
    return $UserID;
}

sub DropSession {
    my ( $Self, %Param ) = @_;
    my $Token = $Param{SessionToken} || return 1;
    my $Hash  = $Self->TokenHash($Token);
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM bwb_pos_session WHERE token_hash = ?',
        Bind => [ \$Hash ],
    );
}

sub Directory {
    my ( $Self, %Param ) = @_;
    my $UserID = $Param{UserID} or return { ok => 0, error => 'unauthorized', status => 401 };
    my $Level  = $Param{Level} || 'customers';
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');

    if ( $Level eq 'customers' ) {
        return { ok => 1, status => 200, customers => $Self->_Customers( UserID => $UserID ) };
    }
    if ( $Level eq 'stores' ) {
        my $CustomerID = $Param{CustomerID} || '';
        return { ok => 0, error => 'need_customer_id', status => 400 } if !$CustomerID;
        return { ok => 0, error => 'forbidden', status => 403 }
            if !$Access->CustomerAccessCheck( UserID => $UserID, CustomerID => $CustomerID );
        return {
            ok     => 1,
            status => 200,
            stores => $Self->_Stores( UserID => $UserID, CustomerID => $CustomerID ),
        };
    }
    if ( $Level eq 'users' ) {
        my $CustomerID = $Param{CustomerID} || '';
        my $StoreID    = $Param{StoreID}    || 0;
        return { ok => 0, error => 'need_customer_store', status => 400 } if !$CustomerID || !$StoreID;
        return { ok => 0, error => 'forbidden', status => 403 }
            if !$Access->StoreAccessCheck( UserID => $UserID, StoreID => $StoreID );
        my %Store = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreGet( StoreID => $StoreID );
        return { ok => 0, error => 'not_found', status => 404 } if !%Store || $Store{CustomerID} ne $CustomerID;
        return {
            ok    => 1,
            status => 200,
            users => $Self->_Users( CustomerID => $CustomerID, StoreID => $StoreID ),
        };
    }
    return { ok => 0, error => 'bad_level', status => 400 };
}

sub Enroll {
    my ( $Self, %Param ) = @_;
    my $UserID       = $Param{UserID} or return { ok => 0, error => 'unauthorized', status => 401 };
    my $CustomerID   = $Param{CustomerID} || '';
    my $StoreID      = $Param{StoreID} || 0;
    my $CustomerUser = $Param{CustomerUser} || '';
    $CustomerID   =~ s/^\s+|\s+$//g;
    $CustomerUser =~ s/^\s+|\s+$//g;
    return { ok => 0, error => 'need_selection', status => 400 }
        if !$CustomerID || !$StoreID || !$CustomerUser;

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    return { ok => 0, error => 'forbidden', status => 403 }
        if !$Access->CustomerAccessCheck( UserID => $UserID, CustomerID => $CustomerID );
    return { ok => 0, error => 'forbidden', status => 403 }
        if !$Access->StoreAccessCheck( UserID => $UserID, StoreID => $StoreID );
    return { ok => 0, error => 'forbidden', status => 403 }
        if !$Access->CustomerUserAccessCheck( UserID => $UserID, CustomerUserLogin => $CustomerUser );

    my %Store = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreGet( StoreID => $StoreID );
    return { ok => 0, error => 'not_found', status => 404 } if !%Store || $Store{CustomerID} ne $CustomerID;

    my %CU = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet( User => $CustomerUser );
    return { ok => 0, error => 'not_found', status => 404 } if !%CU;
    my $UserCustomerID = $CU{UserCustomerID} || $CU{CustomerID} || '';
    return { ok => 0, error => 'mismatch', status => 400 } if $UserCustomerID ne $CustomerID;
    my $UserStoreID = $CU{UserStoreID} || $CU{bwb_store_id} || 0;
    if ( $UserStoreID && int($UserStoreID) != int($StoreID) ) {
        return { ok => 0, error => 'store_user_mismatch', status => 400 };
    }

    my $Plain = $Self->_RandomToken(32);
    my $Hash  = $Self->TokenHash($Plain);
    my $Queue = $Self->QueueForCustomerID($CustomerID);
    my $DB    = $Kernel::OM->Get('Kernel::System::DB');

    my $Station  = $Self->_Clip( $Param{StationNumber}, 16 );
    my $License  = $Self->_Clip( $Param{License},       191 );
    my $Version  = $Self->_Clip( $Param{PosVersion},    64 );
    my $Release  = $Self->_Clip( $Param{PosRelease},    32 );
    my $Hostname = $Self->_Clip( $Param{Hostname},      191 );

    return { ok => 0, error => 'enroll_failed', status => 500 } if !$DB->Do(
        SQL => q{
            INSERT INTO bwb_pos_device (
                token_hash, customer_id, store_id, customer_user, agent_user_id, status,
                station_number, license, pos_version, pos_release, hostname, last_seen,
                create_time, create_by, change_time, change_by
            ) VALUES (
                ?, ?, ?, ?, ?, 'active',
                ?, ?, ?, ?, ?, UTC_TIMESTAMP(),
                UTC_TIMESTAMP(), ?, UTC_TIMESTAMP(), ?
            )
        },
        Bind => [
            \$Hash, \$CustomerID, \$StoreID, \$CustomerUser, \$UserID,
            \$Station, \$License, \$Version, \$Release, \$Hostname,
            \$UserID, \$UserID,
        ],
    );

    $Self->DropSession( SessionToken => $Param{SessionToken} );

    return {
        ok            => 1,
        status        => 200,
        device_token  => $Plain,
        customer_id   => $CustomerID,
        store_id      => int($StoreID),
        store_number  => $Store{StoreNumber},
        store_name    => $Store{StoreName},
        customer_user => $CustomerUser,
        queue         => $Queue,
        status_name   => 'active',
    };
}

sub TicketCreate {
    my ( $Self, %Param ) = @_;
    my $Device = $Self->DeviceByToken( Token => $Param{DeviceToken} );
    return { ok => 0, error => 'unauthorized', status => 401 } if !$Device;

    if ( $Device->{status} eq 'revoked' ) {
        return { ok => 0, error => 'revoked', status => 403 };
    }
    if ( $Device->{status} eq 'suspended' ) {
        return { ok => 0, error => 'suspended', status => 403 };
    }
    if ( $Device->{status} ne 'active' ) {
        return { ok => 0, error => 'inactive', status => 403 };
    }

    my $Title = $Param{Title} // '';
    my $Body  = $Param{Body}  // '';
    $Title =~ s/^\s+|\s+$//g;
    $Body  =~ s/^\s+|\s+$//g;
    return { ok => 0, error => 'need_title_body', status => 400 } if !$Title || !$Body;
    $Title = substr( $Title, 0, MAX_TITLE() );
    $Body  = substr( $Body,  0, MAX_BODY() );

    if ( $Self->_RateLimited( $Device ) ) {
        return { ok => 0, error => 'rate_limited', status => 429 };
    }

    $Self->TouchSnapshot(
        DeviceID      => $Device->{id},
        StationNumber => $Param{StationNumber},
        License       => $Param{License},
        PosVersion    => $Param{PosVersion},
        PosRelease    => $Param{PosRelease},
        Hostname      => $Param{Hostname},
        UserID        => 1,
    );

    my $QueueName = $Self->QueueForCustomerID( $Device->{customer_id} );
    my $QueueID   = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( Queue => $QueueName );
    return { ok => 0, error => 'queue_missing', status => 500 } if !$QueueID;

    my $Meta = join(
        "\n",
        'Pedido enviado do posto PTcert (plugin HELPDESK).',
        'Posto: ' . ( $Param{StationNumber} // $Device->{station_number} // '-' ),
        'Licenca: ' . ( $Param{License} // $Device->{license} // '-' ),
        'Versao: ' . ( $Param{PosVersion} // $Device->{pos_version} // '-' ),
        'Release: ' . ( $Param{PosRelease} // $Device->{pos_release} // '-' ),
        'Hostname: ' . ( $Param{Hostname} // $Device->{hostname} // '-' ),
        '',
        $Body,
    );

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketID     = $TicketObject->TicketCreate(
        Title        => $Title,
        QueueID      => $QueueID,
        Lock         => 'unlock',
        PriorityID   => 3,
        State        => 'open',
        CustomerID   => $Device->{customer_id},
        CustomerUser => $Device->{customer_user},
        OwnerID      => 1,
        UserID       => 1,
    );
    return { ok => 0, error => 'ticket_failed', status => 500 } if !$TicketID;

    $Kernel::OM->Get('Kernel::System::BWBTicketStore')->Set(
        TicketID => $TicketID,
        StoreID  => $Device->{store_id},
        UserID   => 1,
    );

    my %Customer = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Device->{customer_user},
    );
    my $FromName = join(
        ' ',
        grep {$_} ( $Customer{UserFirstname}, $Customer{UserLastname} )
    ) || $Device->{customer_user};
    my $FromEmail = $Customer{UserEmail} || '';
    my $From      = $FromEmail ? "$FromName <$FromEmail>" : $FromName;

    my $ArticleBackend = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
        ChannelName => 'Email',
    );
    my $ArticleID = $ArticleBackend->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'customer',
        IsVisibleForCustomer => 1,
        Subject              => $Title,
        Body                 => $Meta,
        From                 => $From,
        To                   => $QueueName,
        ContentType          => 'text/plain; charset=utf-8',
        HistoryType          => 'EmailCustomer',
        HistoryComment       => 'Ticket criado no POS PTcert',
        UserID               => 1,
    );
    return { ok => 0, error => 'article_failed', status => 500 } if !$ArticleID;

    if ( $Param{LogsBytes} && length $Param{LogsBytes} ) {
        my $Bytes = $Param{LogsBytes};
        if ( length($Bytes) <= MAX_LOGS_BYTES() ) {
            $ArticleBackend->ArticleWriteAttachment(
                Filename    => 'pos-logs.zip',
                Content     => $Bytes,
                ContentType => 'application/zip',
                ArticleID   => $ArticleID,
                UserID      => 1,
            );
        }
    }

    $Self->_BumpTicketWindow( $Device->{id} );

    my $TicketNumber = $TicketObject->TicketNumberLookup( TicketID => $TicketID );
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message  => sprintf(
            'BWBPosDevice: ticket %s device=%s customer=%s store=%s',
            $TicketNumber, $Device->{id}, $Device->{customer_id}, $Device->{store_id},
        ),
    );

    return {
        ok            => 1,
        status        => 200,
        ticket_id     => $TicketID,
        ticket_number => $TicketNumber,
    };
}

sub Contacts {
    my ( $Self, %Param ) = @_;
    my $Device = $Self->DeviceByToken( Token => $Param{DeviceToken} );
    return { ok => 0, error => 'unauthorized', status => 401 } if !$Device;
    return { ok => 0, error => 'revoked',      status => 403 } if $Device->{status} eq 'revoked';
    if ( $Self->_ContactsRateLimited($Device) ) {
        return { ok => 0, error => 'rate_limited', status => 429 };
    }
    my $Ficha = $Kernel::OM->Get('Kernel::System::BWBAocertHelpdesk');
    my $Op    = $Ficha->OperationFromCustomerID( $Device->{customer_id} );
    my $Payload = $Ficha->PublicPayload( Operation => $Op );
    if ( !$Payload ) {
        return { ok => 0, error => 'not_configured', status => 503 };
    }
    $Self->_BumpContactsWindow( $Device->{id} );
    $Payload->{status} = 200;
    return $Payload;
}

sub DeviceByToken {
    my ( $Self, %Param ) = @_;
    my $Token = $Param{Token} || return;
    my $Hash  = $Self->TokenHash($Token);
    return $Self->_DeviceByHash($Hash);
}

sub ListForStore {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{StoreID};
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL => q{
            SELECT d.id, d.customer_id, d.store_id, d.customer_user, d.agent_user_id, d.status,
                   d.station_number, d.license, d.pos_version, d.pos_release, d.hostname,
                   d.last_seen, d.create_time, d.revoked_time, u.login
            FROM bwb_pos_device d
            LEFT JOIN users u ON u.id = d.agent_user_id
            WHERE d.store_id = ?
            ORDER BY d.id DESC
        },
        Bind => [ \$Param{StoreID} ],
    );
    my @Rows;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Rows, {
            id             => $Row[0],
            customer_id    => $Row[1],
            store_id       => $Row[2],
            customer_user  => $Row[3],
            agent_user_id  => $Row[4],
            status         => $Row[5],
            station_number => $Row[6],
            license        => $Row[7],
            pos_version    => $Row[8],
            pos_release    => $Row[9],
            hostname       => $Row[10],
            last_seen      => $Row[11],
            create_time    => $Row[12],
            revoked_time   => $Row[13],
            agent_login    => $Row[14],
        };
    }
    return \@Rows;
}

sub SetStatus {
    my ( $Self, %Param ) = @_;
    my $DeviceID = $Param{DeviceID} or return;
    my $Status   = $Param{Status}   or return;
    my $UserID   = $Param{UserID}   or return;
    return if $Status ne 'active' && $Status ne 'suspended' && $Status ne 'revoked';

    my $Device = $Self->_DeviceByID($DeviceID);
    return if !$Device;
    return if $Device->{status} eq 'revoked';
    return 1 if $Device->{status} eq $Status;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    if ( $Status eq 'revoked' ) {
        return $DB->Do(
            SQL => q{
                UPDATE bwb_pos_device
                SET status = 'revoked', revoked_time = UTC_TIMESTAMP(),
                    change_time = UTC_TIMESTAMP(), change_by = ?
                WHERE id = ? AND status <> 'revoked'
            },
            Bind => [ \$UserID, \$DeviceID ],
        );
    }
    return $DB->Do(
        SQL => q{
            UPDATE bwb_pos_device
            SET status = ?, change_time = UTC_TIMESTAMP(), change_by = ?
            WHERE id = ? AND status <> 'revoked'
        },
        Bind => [ \$Status, \$UserID, \$DeviceID ],
    );
}

sub TouchSnapshot {
    my ( $Self, %Param ) = @_;
    my $DeviceID = $Param{DeviceID} or return;
    my $UserID   = $Param{UserID} || 1;
    my $Station  = $Self->_Clip( $Param{StationNumber}, 16 );
    my $License  = $Self->_Clip( $Param{License},       191 );
    my $Version  = $Self->_Clip( $Param{PosVersion},    64 );
    my $Release  = $Self->_Clip( $Param{PosRelease},    32 );
    my $Hostname = $Self->_Clip( $Param{Hostname},      191 );
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            UPDATE bwb_pos_device
            SET station_number = COALESCE(?, station_number),
                license = COALESCE(?, license),
                pos_version = COALESCE(?, pos_version),
                pos_release = COALESCE(?, pos_release),
                hostname = COALESCE(?, hostname),
                last_seen = UTC_TIMESTAMP(),
                change_time = UTC_TIMESTAMP(),
                change_by = ?
            WHERE id = ?
        },
        Bind => [ \$Station, \$License, \$Version, \$Release, \$Hostname, \$UserID, \$DeviceID ],
    );
}

sub StatusLabel {
    my ( $Self, $Status ) = @_;
    return 'Activo'    if ( $Status || '' ) eq 'active';
    return 'Suspenso'  if ( $Status || '' ) eq 'suspended';
    return 'Revogado'  if ( $Status || '' ) eq 'revoked';
    return $Status || '-';
}

sub _Customers {
    my ( $Self, %Param ) = @_;
    my $Access  = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Company = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my @IDs;
    my $Listed = $Access->CustomerIDsGet( UserID => $Param{UserID} );
    if ($Listed) {
        @IDs = @{$Listed};
    }
    else {
        my %All = $Company->CustomerCompanyList( Valid => 1 );
        @IDs = sort keys %All;
    }
    my @Out;
    for my $CustomerID (@IDs) {
        next if !$Access->CustomerAccessCheck( UserID => $Param{UserID}, CustomerID => $CustomerID );
        my %Data = $Company->CustomerCompanyGet( CustomerID => $CustomerID );
        next if !%Data;
        next if ( $Data{ValidID} || 1 ) != 1;
        push @Out, {
            customer_id => $CustomerID,
            name        => $Data{CustomerCompanyName} || $CustomerID,
            queue       => $Self->QueueForCustomerID($CustomerID),
        };
    }
    return \@Out;
}

sub _Stores {
    my ( $Self, %Param ) = @_;
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $List   = $Kernel::OM->Get('Kernel::System::BWBStore')->StoreList(
        CustomerID => $Param{CustomerID},
    );
    my @Out;
    for my $Store ( @{$List} ) {
        next if !$Access->StoreAccessCheck( UserID => $Param{UserID}, StoreID => $Store->{StoreID} );
        push @Out, {
            store_id     => int( $Store->{StoreID} ),
            store_number => $Store->{StoreNumber},
            name         => $Store->{StoreName},
            street       => $Store->{StoreStreet} || '',
        };
    }
    return \@Out;
}

sub _Users {
    my ( $Self, %Param ) = @_;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL => q{
            SELECT login, first_name, last_name, email, bwb_store_id
            FROM customer_user
            WHERE customer_id = ? AND valid_id = 1
              AND (bwb_store_id = ? OR bwb_store_id IS NULL OR bwb_store_id = 0)
            ORDER BY login
        },
        Bind => [ \$Param{CustomerID}, \$Param{StoreID} ],
    );
    my @Out;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $StoreID = $Row[4] || 0;
        next if $StoreID && int($StoreID) != int( $Param{StoreID} );
        push @Out, {
            login      => $Row[0],
            first_name => $Row[1] || '',
            last_name  => $Row[2] || '',
            email      => $Row[3] || '',
        };
    }
    return \@Out;
}

sub _SessionCreate {
    my ( $Self, %Param ) = @_;
    my $Plain = $Self->_RandomToken(32);
    my $Hash  = $Self->TokenHash($Plain);
    my $TTL   = SESSION_TTL_SECONDS();
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            INSERT INTO bwb_pos_session (token_hash, user_id, remote_addr, expires)
            VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL ? SECOND))
        },
        Bind => [ \$Hash, \$Param{UserID}, \$Param{RemoteAddr}, \$TTL ],
    );
    return $Plain;
}

sub _AuthLocked {
    my ( $Self, %Param ) = @_;
    my $DB  = $Kernel::OM->Get('Kernel::System::DB');
    my $Win = AUTH_FAIL_WINDOW();
    my $Max = AUTH_FAIL_MAX();
    return 0 if !$DB->Prepare(
        SQL => q{
            SELECT fail_count FROM bwb_pos_auth_fail
            WHERE remote_addr = ?
              AND window_start >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND)
              AND fail_count >= ?
        },
        Bind  => [ \$Param{RemoteAddr}, \$Win, \$Max ],
        Limit => 1,
    );
    my ($Count) = $DB->FetchrowArray();
    return $Count ? 1 : 0;
}

sub _AuthFail {
    my ( $Self, %Param ) = @_;
    my $DB  = $Kernel::OM->Get('Kernel::System::DB');
    my $Max = AUTH_FAIL_MAX();
    my $Win = AUTH_FAIL_WINDOW();
    $DB->Do(
        SQL => q{
            INSERT INTO bwb_pos_auth_fail (remote_addr, fail_count, window_start)
            VALUES (?, 1, UTC_TIMESTAMP())
            ON DUPLICATE KEY UPDATE
                fail_count = IF(
                    window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    1,
                    fail_count + 1
                ),
                window_start = IF(
                    window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    UTC_TIMESTAMP(),
                    window_start
                )
        },
        Bind => [ \$Param{RemoteAddr}, \$Win, \$Win ],
    );
}

sub _AuthClear {
    my ( $Self, %Param ) = @_;
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM bwb_pos_auth_fail WHERE remote_addr = ?',
        Bind => [ \$Param{RemoteAddr} ],
    );
}

sub _DeviceByHash {
    my ( $Self, $Hash ) = @_;
    return if !$Hash;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => q{
            SELECT id, customer_id, store_id, customer_user, agent_user_id, status,
                   station_number, license, pos_version, pos_release, hostname,
                   ticket_window_start, ticket_window_count,
                   contacts_window_start, contacts_window_count
            FROM bwb_pos_device WHERE token_hash = ?
        },
        Bind  => [ \$Hash ],
        Limit => 1,
    );
    my @Row = $DB->FetchrowArray();
    return if !@Row;
    return $Self->_RowToDevice(@Row);
}

sub _DeviceByID {
    my ( $Self, $ID ) = @_;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => q{
            SELECT id, customer_id, store_id, customer_user, agent_user_id, status,
                   station_number, license, pos_version, pos_release, hostname,
                   ticket_window_start, ticket_window_count,
                   contacts_window_start, contacts_window_count
            FROM bwb_pos_device WHERE id = ?
        },
        Bind  => [ \$ID ],
        Limit => 1,
    );
    my @Row = $DB->FetchrowArray();
    return if !@Row;
    return $Self->_RowToDevice(@Row);
}

sub _RowToDevice {
    my ( $Self, @Row ) = @_;
    return {
        id                   => $Row[0],
        customer_id          => $Row[1],
        store_id             => $Row[2],
        customer_user        => $Row[3],
        agent_user_id        => $Row[4],
        status               => $Row[5],
        station_number       => $Row[6],
        license              => $Row[7],
        pos_version          => $Row[8],
        pos_release          => $Row[9],
        hostname             => $Row[10],
        ticket_window_start    => $Row[11],
        ticket_window_count    => $Row[12],
        contacts_window_start  => $Row[13],
        contacts_window_count  => $Row[14],
    };
}

sub _RateLimited {
    my ( $Self, $Device ) = @_;
    my $Start = $Device->{ticket_window_start} || '';
    my $Count = $Device->{ticket_window_count} || 0;
    return 0 if !$Start;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return 0 if !$DB->Prepare(
        SQL   => 'SELECT UTC_TIMESTAMP() < DATE_ADD(?, INTERVAL ? SECOND)',
        Bind  => [ \$Start, \TICKET_WINDOW_SECONDS() ],
        Limit => 1,
    );
    my ($InWindow) = $DB->FetchrowArray();
    return $InWindow && $Count >= TICKET_WINDOW_MAX() ? 1 : 0;
}

sub _BumpTicketWindow {
    my ( $Self, $DeviceID ) = @_;
    my $Max = TICKET_WINDOW_MAX();
    my $Win = TICKET_WINDOW_SECONDS();
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            UPDATE bwb_pos_device
            SET ticket_window_count = IF(
                    ticket_window_start IS NULL
                    OR ticket_window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    1,
                    ticket_window_count + 1
                ),
                ticket_window_start = IF(
                    ticket_window_start IS NULL
                    OR ticket_window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    UTC_TIMESTAMP(),
                    ticket_window_start
                )
            WHERE id = ?
        },
        Bind => [ \$Win, \$Win, \$DeviceID ],
    );
}

sub _ContactsRateLimited {
    my ( $Self, $Device ) = @_;
    my $Start = $Device->{contacts_window_start} || '';
    my $Count = $Device->{contacts_window_count} || 0;
    return 0 if !$Start;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return 0 if !$DB->Prepare(
        SQL   => 'SELECT UTC_TIMESTAMP() < DATE_ADD(?, INTERVAL ? SECOND)',
        Bind  => [ \$Start, \CONTACTS_WINDOW_SECONDS() ],
        Limit => 1,
    );
    my ($InWindow) = $DB->FetchrowArray();
    return $InWindow && $Count >= CONTACTS_WINDOW_MAX() ? 1 : 0;
}

sub _BumpContactsWindow {
    my ( $Self, $DeviceID ) = @_;
    my $Win = CONTACTS_WINDOW_SECONDS();
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{
            UPDATE bwb_pos_device
            SET contacts_window_count = IF(
                    contacts_window_start IS NULL
                    OR contacts_window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    1,
                    contacts_window_count + 1
                ),
                contacts_window_start = IF(
                    contacts_window_start IS NULL
                    OR contacts_window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND),
                    UTC_TIMESTAMP(),
                    contacts_window_start
                ),
                last_seen = UTC_TIMESTAMP()
            WHERE id = ?
        },
        Bind => [ \$Win, \$Win, \$DeviceID ],
    );
}

sub _Clip {
    my ( $Self, $Value, $Max ) = @_;
    return undef if !defined $Value || $Value eq '';
    $Value =~ s/[\r\n\t]+/ /g;
    $Value =~ s/^\s+|\s+$//g;
    return undef if $Value eq '';
    return substr( $Value, 0, $Max );
}

1;
