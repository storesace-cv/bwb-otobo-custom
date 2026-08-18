package Kernel::System::BWBTimeSpent;

use strict;
use warnings;
use utf8;

# Clientes de teste excluídos do relatório Tempo dispendido (ecrã e PDF).
# BWB → 1008; ZS Angola → 1009.
my $TEST_CUSTOMER_BWB = '1008';
my $TEST_CUSTOMER_ZS  = '1009';

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBStore',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DateTime',
    'Kernel::System::DB',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub TeamSessionsInPeriodGet {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID} || !$Param{FromUTC} || !$Param{ToUTC};

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $ResponsibleUserID = $AccessObject->ResponsibleUserIDGet( UserID => $Param{UserID} ) || $Param{UserID};
    my $ExcludeCustomerID = $AccessObject->IsZSOperationUser( UserID => $Param{UserID} )
        ? $TEST_CUSTOMER_ZS
        : $TEST_CUSTOMER_BWB;

    my ( $SQL, @BindValues );
    my $Select = q{
            SELECT s.id, s.ticket_id, s.user_id, s.work_type, s.start_time, s.end_time,
                   s.duration_minutes, s.result,
                   w.paused_at, COALESCE(w.paused_seconds, 0),
                   GREATEST(0, TIMESTAMPDIFF(SECOND, s.start_time, UTC_TIMESTAMP())
                     - COALESCE(w.paused_seconds, 0)
                     - CASE WHEN w.paused_at IS NULL THEN 0
                            ELSE TIMESTAMPDIFF(SECOND, w.paused_at, UTC_TIMESTAMP()) END)
            FROM bwb_work_session s
            LEFT JOIN bwb_work_sheet w ON w.session_id = s.id
    };
    my $Overlap = q{
              AND s.start_time <= ?
              AND (s.end_time IS NULL OR s.end_time >= ?)
    };

    if ( $AccessObject->IsGlobalAdministrator( UserID => $Param{UserID} ) ) {
        $SQL = $Select . q{ WHERE 1=1 } . $Overlap . q{ ORDER BY s.start_time ASC };
        @BindValues = ( $Param{ToUTC}, $Param{FromUTC} );
    }
    elsif ( int($ResponsibleUserID) == int( $Param{UserID} ) ) {
        $SQL = $Select . q{
            LEFT JOIN bwb_agent_hierarchy h ON h.user_id = s.user_id
            WHERE (s.user_id = ? OR h.responsible_user_id = ?)
        } . $Overlap . q{ ORDER BY s.start_time ASC };
        @BindValues = ( $Param{UserID}, $Param{UserID}, $Param{ToUTC}, $Param{FromUTC} );
    }
    else {
        $SQL = $Select . q{ WHERE s.user_id = ? } . $Overlap . q{ ORDER BY s.start_time ASC };
        @BindValues = ( $Param{UserID}, $Param{ToUTC}, $Param{FromUTC} );
    }

    my @Bind = map { \$BindValues[$_] } 0 .. $#BindValues;
    return [] if !$DBObject->Prepare( SQL => $SQL, Bind => \@Bind );

    my @Raw;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Raw, [@Data];
    }

    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUser    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $CustomerCompany = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my $StoreObject     = $Kernel::OM->Get('Kernel::System::BWBStore');
    my $TimeZone        = $Param{TimeZone} || 'Europe/Lisbon';
    my %UserCache;
    my %StoreCache;
    my %CompanyNameCache;

    my @Rows;
    for my $Data (@Raw) {
        my (
            $SessionID, $TicketID, $TechnicianID, $WorkType, $StartUTC, $EndUTC,
            $DurationMinutes, $Result, $PausedAt, $PausedSeconds, $ActiveSeconds
        ) = @{$Data};

        next if !$AccessObject->TicketAccessCheck(
            UserID   => $Param{UserID},
            TicketID => $TicketID,
        );

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
            Silent        => 1,
        );
        next if !%Ticket;

        my $CustomerID = $Ticket{CustomerID} || '';
        next if $CustomerID && $CustomerID eq $ExcludeCustomerID;

        if ( !$UserCache{$TechnicianID} ) {
            my %Technician = $UserObject->GetUserData( UserID => $TechnicianID );
            $UserCache{$TechnicianID} = $Technician{UserFullname} || $Technician{UserLogin} || '-';
        }

        my $Customer = $Ticket{CustomerCompanyName} || $Ticket{CustomerName} || '';
        if ( !$Customer && $CustomerID ) {
            if ( !exists $CompanyNameCache{$CustomerID} ) {
                my %Company = $CustomerCompany->CustomerCompanyGet(
                    CustomerID => $CustomerID,
                );
                $CompanyNameCache{$CustomerID} = $Company{CustomerCompanyName} || $CustomerID;
            }
            $Customer = $CompanyNameCache{$CustomerID};
        }
        $Customer ||= $CustomerID || '-';

        my $Store            = '-';
        my $CustomerUserName = '-';
        if ( $Ticket{CustomerUserID} ) {
            my %CU = $CustomerUser->CustomerUserDataGet( User => $Ticket{CustomerUserID} );
            $CustomerUserName = join ' ',
                grep { defined $_ && length $_ } @CU{qw(UserFirstname UserLastname)};
            $CustomerUserName ||= $CU{UserFullname} || $CU{UserLogin} || $Ticket{CustomerUserID} || '-';
            my $StoreID = $CU{UserStoreID} || 0;
            if ($StoreID) {
                if ( !exists $StoreCache{$StoreID} ) {
                    my %StoreData = $StoreObject->StoreGet( StoreID => $StoreID );
                    my $Label     = '-';
                    if (%StoreData) {
                        $Label = join ' - ', grep {$_} ( $StoreData{StoreNumber}, $StoreData{StoreName} );
                    }
                    $StoreCache{$StoreID} = $Label || '-';
                }
                $Store = $StoreCache{$StoreID};
            }
        }

        my $Closed      = $EndUTC ? 1 : 0;
        my $Minutes     = $Closed ? int( $DurationMinutes || 0 ) : int( ( $ActiveSeconds || 0 ) / 60 );
        my $Status      = 'Terminada';
        my $StatusClass = 'BWBClosed';
        if ( !$Closed ) {
            $Status      = $PausedAt ? 'Em pausa' : 'Em execução';
            $StatusClass = $PausedAt ? 'BWBPaused' : 'BWBRunning';
        }

        my $StartStamp = $Self->_FormatStamp( $StartUTC, $TimeZone );
        my $StartDate  = '-';
        if ( $StartStamp =~ /^(\d{2}\/\d{2}\/\d{4})/ ) {
            $StartDate = $1;
        }

        push @Rows, {
            SessionID        => $SessionID,
            TicketID         => $TicketID,
            TicketNumber     => $Ticket{TicketNumber},
            Title            => $Ticket{Title} || '-',
            CustomerID       => $CustomerID,
            Customer         => $Customer,
            CustomerUserName => $CustomerUserName,
            Store            => $Store,
            Technician       => $UserCache{$TechnicianID},
            WorkType         => $WorkType || '-',
            Status           => $Status,
            StatusClass      => $StatusClass,
            Start            => $StartStamp,
            StartDate        => $StartDate,
            End              => $Closed ? $Self->_FormatStamp( $EndUTC, $TimeZone ) : '—',
            StartSort        => $StartUTC || '',
            Minutes          => $Minutes,
            Duration         => $Self->FormatMinutes($Minutes),
            Result           => $Closed ? ( $Result || '—' ) : '—',
            Closed           => $Closed,
        };
    }

    @Rows = sort {
        lc( $a->{Customer} ) cmp lc( $b->{Customer} )
            || lc( $a->{Store} ) cmp lc( $b->{Store} )
            || ( $a->{StartSort} cmp $b->{StartSort} )
    } @Rows;

    return \@Rows;
}

sub TotalsFromRows {
    my ( $Self, $Rows ) = @_;
    $Rows ||= [];
    my %ByStore;
    my %ByCustomer;
    my $Grand = 0;
    for my $Row ( @{$Rows} ) {
        my $Minutes  = int( $Row->{Minutes} || 0 );
        my $Customer = $Row->{Customer} || '-';
        my $Store    = $Row->{Store}    || '-';
        $Grand += $Minutes;
        $ByCustomer{$Customer} += $Minutes;
        $ByStore{ $Customer . "\t" . $Store }{Customer} = $Customer;
        $ByStore{ $Customer . "\t" . $Store }{Store}    = $Store;
        $ByStore{ $Customer . "\t" . $Store }{Minutes} += $Minutes;
    }
    my @StoreTotals = map {
        {
            Customer => $_->{Customer},
            Store    => $_->{Store},
            Minutes  => $_->{Minutes},
            Duration => $Self->FormatMinutes( $_->{Minutes} ),
        }
    } sort {
        lc( $a->{Customer} ) cmp lc( $b->{Customer} )
            || lc( $a->{Store} ) cmp lc( $b->{Store} )
    } values %ByStore;

    my @CustomerTotals = map {
        {
            Customer => $_,
            Minutes  => $ByCustomer{$_},
            Duration => $Self->FormatMinutes( $ByCustomer{$_} ),
        }
    } sort { lc($a) cmp lc($b) } keys %ByCustomer;

    return {
        Store    => \@StoreTotals,
        Customer => \@CustomerTotals,
        Grand    => $Grand,
        Duration => $Self->FormatMinutes($Grand),
        Count    => scalar @{$Rows},
    };
}

sub CustomerSummariesFromRows {
    my ( $Self, $Rows ) = @_;
    $Rows ||= [];

    my %ByCustomerID;
    for my $Row ( @{$Rows} ) {
        my $CustomerID = $Row->{CustomerID} || '';
        my $Key        = $CustomerID ne '' ? $CustomerID : ( 'name:' . ( $Row->{Customer} || '-' ) );
        push @{ $ByCustomerID{$Key}{Rows} }, $Row;
        $ByCustomerID{$Key}{CustomerID} = $CustomerID;
        $ByCustomerID{$Key}{Customer}   = $Row->{Customer} || '-';
    }

    my $CustomerCompany = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my @Summaries;

    for my $Key (
        sort {
            lc( $ByCustomerID{$a}{Customer} ) cmp lc( $ByCustomerID{$b}{Customer} )
                || ( $ByCustomerID{$a}{CustomerID} cmp $ByCustomerID{$b}{CustomerID} )
        } keys %ByCustomerID
        )
    {
        my $Group = $ByCustomerID{$Key};
        my @GroupRows = sort {
            lc( $a->{Store} ) cmp lc( $b->{Store} )
                || ( $a->{StartSort} cmp $b->{StartSort} )
        } @{ $Group->{Rows} };

        my %Header = (
            CustomerID   => $Group->{CustomerID},
            CustomerName => $Group->{Customer},
            Street       => '',
            ZIP          => '',
            City         => '',
            Country      => '',
            Phone        => '',
        );
        if ( $Group->{CustomerID} ) {
            my %Company = $CustomerCompany->CustomerCompanyGet(
                CustomerID => $Group->{CustomerID},
            );
            if (%Company) {
                $Header{CustomerName} = $Company{CustomerCompanyName} || $Header{CustomerName};
                $Header{Street}       = $Company{CustomerCompanyStreet}  || '';
                $Header{ZIP}          = $Company{CustomerCompanyZIP}     || '';
                $Header{City}         = $Company{CustomerCompanyCity}    || '';
                $Header{Country}      = $Company{CustomerCompanyCountry} || '';
                $Header{Phone}        = $Company{CustomerCompanyPhone}   || '';
            }
        }

        my $Totals = $Self->TotalsFromRows( \@GroupRows );
        push @Summaries, {
            Header => \%Header,
            Rows   => \@GroupRows,
            Totals => $Totals,
        };
    }

    return \@Summaries;
}

sub FormatMinutes {
    my ( $Self, $Minutes ) = @_;
    $Minutes = int( $Minutes || 0 );
    return '0 min' if $Minutes <= 0;
    return "$Minutes min" if $Minutes < 60;
    my $Hours = int( $Minutes / 60 );
    my $Rest  = $Minutes % 60;
    return $Rest ? "$Hours h $Rest min" : "$Hours h";
}

sub PeriodToUTC {
    my ( $Self, %Param ) = @_;
    my $TimeZone = $Param{TimeZone} || 'Europe/Lisbon';
    my $FromDate = $Param{FromDate} || '';
    my $ToDate   = $Param{ToDate}   || '';
    return if $FromDate !~ /^\d{4}-\d{2}-\d{2}$/ || $ToDate !~ /^\d{4}-\d{2}-\d{2}$/;
    if ( $FromDate gt $ToDate ) {
        ( $FromDate, $ToDate ) = ( $ToDate, $FromDate );
    }

    my $From = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => { String => "$FromDate 00:00:00", TimeZone => $TimeZone },
    );
    my $To = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => { String => "$ToDate 23:59:59", TimeZone => $TimeZone },
    );
    return if !$From || !$To;
    $From->ToTimeZone( TimeZone => 'UTC' );
    $To->ToTimeZone( TimeZone => 'UTC' );
    return {
        FromDate => $FromDate,
        ToDate   => $ToDate,
        FromUTC  => $From->Format( Format => '%Y-%m-%d %H:%M:%S' ),
        ToUTC    => $To->Format( Format => '%Y-%m-%d %H:%M:%S' ),
    };
}

sub DefaultDates {
    my ( $Self, %Param ) = @_;
    my $TimeZone = $Param{TimeZone} || 'Europe/Lisbon';
    my $Now      = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => { TimeZone => $TimeZone },
    );
    return (
        $Now->Format( Format => '%Y-%m-01' ),
        $Now->Format( Format => '%Y-%m-%d' ),
    );
}

sub _FormatStamp {
    my ( $Self, $UTC, $TimeZone ) = @_;
    return '—' if !$UTC;
    my $Object = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => { String => $UTC, TimeZone => 'UTC' },
    );
    return $UTC if !$Object;
    $Object->ToTimeZone( TimeZone => $TimeZone || 'Europe/Lisbon' );
    return $Object->Format( Format => '%d/%m/%Y %H:%M' );
}

1;
