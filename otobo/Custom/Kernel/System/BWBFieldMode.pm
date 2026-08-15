package Kernel::System::BWBFieldMode;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub IsCollaborator {
    my ( $Self, %Param ) = @_;
    return 0 if !$Param{UserID};
    return 0 if $Kernel::OM->Get('Kernel::System::BWBAccess')->IsGlobalAdministrator(
        UserID => $Param{UserID},
    );
    my $ResponsibleUserID = $Kernel::OM->Get('Kernel::System::BWBAccess')->ResponsibleUserIDGet(
        UserID => $Param{UserID},
    );
    return ( $ResponsibleUserID && $ResponsibleUserID != $Param{UserID} ) ? 1 : 0;
}

sub PreferenceGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Param{UserID},
    );
    my $Value = $Preferences{UserBWBFieldMode};
    return if !defined $Value || $Value eq '';
    return $Value;
}

sub PreferenceSet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !defined $Param{Value};
    return $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
        UserID => $Param{UserID},
        Key    => 'UserBWBFieldMode',
        Value  => $Param{Value} ? '1' : '0',
    );
}

sub DefaultQueueName {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my $ResponsibleUserID = $Kernel::OM->Get('Kernel::System::BWBAccess')->ResponsibleUserIDGet(
        UserID => $Param{UserID},
    ) || $Param{UserID};
    # Amadeu (UserID 4) owns ZS queues; remaining BWB/StoresAce scope uses bwb-in.
    return $ResponsibleUserID == 4 ? 'zsangola-in' : 'bwb-in';
}

1;
