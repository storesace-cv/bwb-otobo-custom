package Kernel::Config::Files::ZZZBWBTimeCalendars;

use strict;
use warnings;
use utf8;
use Time::Local qw(timegm);

sub _AddDays {
    my ( $Year, $Month, $Day, $Offset ) = @_;
    my $Epoch = timegm( 0, 0, 12, $Day, $Month - 1, $Year ) + ( $Offset * 86_400 );
    my @Date = gmtime($Epoch);
    return ( $Date[5] + 1900, $Date[4] + 1, $Date[3], $Date[6] );
}

sub _EasterSunday {
    my ($Year) = @_;
    my $A = $Year % 19;
    my $B = int( $Year / 100 );
    my $C = $Year % 100;
    my $D = int( $B / 4 );
    my $E = $B % 4;
    my $F = int( ( $B + 8 ) / 25 );
    my $G = int( ( $B - $F + 1 ) / 3 );
    my $H = ( 19 * $A + $B - $D - $G + 15 ) % 30;
    my $I = int( $C / 4 );
    my $K = $C % 4;
    my $L = ( 32 + 2 * $E + 2 * $I - $H - $K ) % 7;
    my $M = int( ( $A + 11 * $H + 22 * $L ) / 451 );
    my $Month = int( ( $H + $L - 7 * $M + 114 ) / 31 );
    my $Day = ( $H + $L - 7 * $M + 114 ) % 31 + 1;
    return ( $Year, $Month, $Day );
}

sub Load {
    my ( $File, $Self ) = @_;

    my $AllHours = [ 0 .. 23 ];
    my $EveryDay = {
        Mon => [@{$AllHours}],
        Tue => [@{$AllHours}],
        Wed => [@{$AllHours}],
        Thu => [@{$AllHours}],
        Fri => [@{$AllHours}],
        Sat => [@{$AllHours}],
        Sun => [@{$AllHours}],
    };

    $Self->{'TimeZone::Calendar1Name'}              = 'BWB - Portugal 24x7';
    $Self->{'TimeZone::Calendar1'}                  = 'Europe/Lisbon';
    $Self->{'TimeWorkingHours::Calendar1'}          = $EveryDay;
    $Self->{'TimeVacationDays::Calendar1'}          = {};
    $Self->{'TimeVacationDaysOneTime::Calendar1'}   = {};

    my $ZSWorkingHours = {
        Mon => [ 8 .. 16 ],
        Tue => [ 8 .. 16 ],
        Wed => [ 8 .. 16 ],
        Thu => [ 8 .. 16 ],
        Fri => [ 8 .. 16 ],
        Sat => [],
        Sun => [],
    };

    my $ZSFixedHolidays = {
        1  => { 1  => 'Ano Novo' },
        2  => { 4  => 'Início da Luta Armada de Libertação Nacional' },
        3  => {
            8  => 'Dia Internacional da Mulher',
            23 => 'Dia da Libertação da África Austral',
        },
        4  => { 4  => 'Dia da Paz e da Reconciliação Nacional' },
        5  => { 1  => 'Dia Internacional do Trabalhador' },
        9  => { 17 => 'Dia do Fundador da Nação e do Herói Nacional' },
        11 => {
            2  => 'Dia dos Finados',
            11 => 'Dia da Independência',
        },
        12 => { 25 => 'Dia de Natal e da Família' },
    };

    my $ZSOneTimeHolidays = {};
    for my $Year ( 2026 .. 2035 ) {
        my @Holidays;
        for my $Month ( keys %{$ZSFixedHolidays} ) {
            for my $Day ( keys %{ $ZSFixedHolidays->{$Month} } ) {
                push @Holidays, [ $Year, $Month, $Day ];
            }
        }

        my ( $EY, $EM, $ED ) = _EasterSunday($Year);
        my ( $CY, $CM, $CD ) = _AddDays( $EY, $EM, $ED, -47 );
        my ( $GY, $GM, $GD ) = _AddDays( $EY, $EM, $ED, -2 );
        $ZSOneTimeHolidays->{$CY}->{$CM}->{$CD} = 'Carnaval';
        $ZSOneTimeHolidays->{$GY}->{$GM}->{$GD} = 'Sexta-Feira Santa';
        push @Holidays, [ $CY, $CM, $CD ], [ $GY, $GM, $GD ];

        for my $Holiday (@Holidays) {
            my ( $HY, $HM, $HD, $WeekDay ) = _AddDays( @{$Holiday}, 0 );
            my $BridgeOffset = $WeekDay == 2 ? -1 : $WeekDay == 4 ? 1 : 0;
            next if !$BridgeOffset;
            my ( $BY, $BM, $BD ) = _AddDays( $HY, $HM, $HD, $BridgeOffset );
            $ZSOneTimeHolidays->{$BY}->{$BM}->{$BD} = 'Ponte legal';
        }
    }

    $Self->{'TimeZone::Calendar2Name'}              = 'ZS Angola - 08h00-17h00';
    # OTOBO 11's bundled time-zone database has no Africa/Luanda entry.
    # Africa/Lagos has the same UTC+1 offset and no daylight-saving changes.
    $Self->{'TimeZone::Calendar2'}                  = 'Africa/Lagos';
    $Self->{'TimeWorkingHours::Calendar2'}          = $ZSWorkingHours;
    $Self->{'TimeVacationDays::Calendar2'}          = $ZSFixedHolidays;
    $Self->{'TimeVacationDaysOneTime::Calendar2'}   = $ZSOneTimeHolidays;

    return;
}

1;
