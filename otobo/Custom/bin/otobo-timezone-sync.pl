#!/usr/bin/perl

use v5.24;
use strict;
use warnings;

use lib '/opt/otobo';
use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
my $GroupObject        = $Kernel::OM->Get('Kernel::System::Group');
my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

my $ChangedAgents    = 0;
my $ChangedCustomers = 0;

sub SetAgentTimeZone {
    my ( $UserID, $TimeZone ) = @_;
    my %Preferences = $UserObject->GetPreferences( UserID => $UserID );
    return if ( $Preferences{UserTimeZone} // '' ) eq $TimeZone;
    $UserObject->SetPreferences(
        UserID => $UserID,
        Key    => 'UserTimeZone',
        Value  => $TimeZone,
    ) or die "Could not set time zone for agent ID $UserID\n";
    $ChangedAgents++;
}

my $ZSGroupID = $GroupObject->GroupLookup( Group => 'ZS Angola' )
    or die "Group 'ZS Angola' not found\n";
my %ZSAgents = $GroupObject->PermissionGroupUserGet(
    GroupID => $ZSGroupID,
    Type    => 'ro',
);
for my $UserID ( keys %ZSAgents ) {
    SetAgentTimeZone( $UserID, 'Africa/Lagos' );
}

my $JorgeID = $UserObject->UserLookup( UserLogin => 'jorge.peixinho' )
    or die "Agent jorge.peixinho not found\n";
SetAgentTimeZone( $JorgeID, 'Europe/Lisbon' );

my %CountryTimeZone = (
    portugal     => 'Europe/Lisbon',
    angola       => 'Africa/Lagos',
    'cabo verde' => 'Atlantic/Cape_Verde',
);
my %CustomerUsers = $CustomerUserObject->CustomerSearch(
    Search => '*',
    Valid  => 1,
    Limit  => 100000,
);
for my $Login ( keys %CustomerUsers ) {
    my %Data = $CustomerUserObject->CustomerUserDataGet( User => $Login );
    next if !%Data;
    my $Country = lc( $Data{UserCountry} // '' );
    $Country =~ s{\A\s+|\s+\z}{}g;
    my $TimeZone = $CountryTimeZone{$Country} // 'Europe/Lisbon';
    my %Preferences = $CustomerUserObject->GetPreferences( UserID => $Login );
    next if ( $Preferences{UserTimeZone} // '' ) eq $TimeZone;
    $CustomerUserObject->SetPreferences(
        UserID => $Login,
        Key    => 'UserTimeZone',
        Value  => $TimeZone,
    ) or die "Could not set time zone for customer user $Login\n";
    $ChangedCustomers++;
}

print "Time-zone sync complete: agents=$ChangedAgents customers=$ChangedCustomers\n";
