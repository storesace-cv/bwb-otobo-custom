package Kernel::System::BWBDashboard;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AuthSession',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

# OTOBO AgentDashboardCommon: se UserDashboardPosition já existe, widgets
# ausentes dessa lista são sempre append (fundo). O prefixo 0129/0126/… só
# ordena dashboards sem preferência gravada. Aqui inserimos os em falta
# imediatamente antes do sucessor canónico (ordem das chaves DashboardBackend).
sub AgentPositionEnsure {
    my ( $Self, %Param ) = @_;

    my $UserID    = $Param{UserID}    || 0;
    my $SessionID = $Param{SessionID} || '';
    my $Session   = $Param{Session};
    return if !$UserID || !$SessionID || ref $Session ne 'HASH';

    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('DashboardBackend') || {};
    return 1 if ref $Config ne 'HASH' || !%{$Config};

    my @Canonical = sort keys %{$Config};
    my $PrefKey   = 'UserDashboardPosition';
    my $Value     = $Session->{$PrefKey};
    return 1 if !defined $Value || $Value eq '';

    my @Order = grep { length } split /;/, $Value;
    my %Seen  = map { $_ => 1 } @Order;

    my $Changed = 0;
    NAME:
    for my $Name (@Canonical) {
        next NAME if $Seen{$Name};

        my $Inserted = 0;
        my $After    = 0;
        SUCCESSOR:
        for my $Canon (@Canonical) {
            if ( $Canon eq $Name ) {
                $After = 1;
                next SUCCESSOR;
            }
            next SUCCESSOR if !$After;
            next SUCCESSOR if !$Seen{$Canon};

            INDEX:
            for my $Index ( 0 .. $#Order ) {
                next INDEX if $Order[$Index] ne $Canon;
                splice @Order, $Index, 0, $Name;
                $Inserted = 1;
                last INDEX;
            }
            last SUCCESSOR if $Inserted;
        }
        if ( !$Inserted ) {
            push @Order, $Name;
        }
        $Seen{$Name} = 1;
        $Changed = 1;
    }

    return 1 if !$Changed;

    my $Data = join( ';', @Order );
    $Data .= ';' if $Data ne '';

    $Session->{$PrefKey} = $Data;

    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $SessionID,
        Key       => $PrefKey,
        Value     => $Data,
    );

    if ( !$Kernel::OM->Get('Kernel::Config')->Get('DemoSystem') ) {
        $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
            UserID => $UserID,
            Key    => $PrefKey,
            Value  => $Data,
        );
    }

    return 1;
}

1;
