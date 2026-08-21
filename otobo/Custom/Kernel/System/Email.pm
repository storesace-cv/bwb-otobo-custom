# --
# Custom Email: injecta X-BWB-* via BWBEmailContext; delega o resto ao núcleo.
# Não copiar o Email.pm do núcleo para o Git — carrega-o como Email::Core.
# --
package Kernel::System::Email;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

# Dependências do núcleo + BWB (Object Manager injeta no new() desta package).
our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBEmailContext',
    'Kernel::System::Crypt::PGP',
    'Kernel::System::Crypt::SMIME',
    'Kernel::System::Encode',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::MailQueue',
    'Kernel::System::CommunicationLog',
);

BEGIN {
    return if $Kernel::System::Email::BWBCoreLoaded;

    my $Home = $ENV{OTOBO_HOME} || '/opt/otobo';
    my $File = "$Home/Kernel/System/Email.pm";
    if ( !-f $File ) {
        die "BWB Email wrapper: núcleo não encontrado em $File (defina OTOBO_HOME).\n";
    }

    open my $Fh, '<:encoding(UTF-8)', $File or die "Cannot read $File: $!\n";
    local $/;
    my $Source = <$Fh>;
    close $Fh;

    $Source =~ s{^package\s+Kernel::System::Email\s*;}{package Kernel::System::Email::Core;}m
        or die "BWB Email wrapper: package Kernel::System::Email não encontrado em $File.\n";

    {
        local $Kernel::System::Email::BWBCoreLoaded = 1;
        ## no critic (BuiltinFunctions::ProhibitStringyEval)
        eval $Source;    ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
        die $@ if $@;
    }
    $Kernel::System::Email::BWBCoreLoaded = 1;
}

our @ISA = ('Kernel::System::Email::Core');    ## no critic (ClassHierarchies::ProhibitExplicitISA)

sub Send {
    my ( $Self, %Param ) = @_;

    %Param = $Kernel::OM->Get('Kernel::System::BWBEmailContext')->MergeCustomHeaders(
        Send => \%Param,
    );

    return $Self->SUPER::Send(%Param);
}

1;
