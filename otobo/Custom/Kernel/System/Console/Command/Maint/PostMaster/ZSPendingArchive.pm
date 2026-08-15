package Kernel::System::Console::Command::Maint::PostMaster::ZSPendingArchive;

use strict;
use warnings;
use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = ('Kernel::System::BWBZSIMAP');

sub Configure {
    my ($Self) = @_;
    $Self->Description('Move ZS pending messages older than 30 days to Outros - Emails.');
    return;
}

sub Run {
    my ($Self) = @_;
    my $Moved = $Kernel::OM->Get('Kernel::System::BWBZSIMAP')->ArchiveExpired();
    if ( !defined $Moved ) {
        $Self->PrintError('Não foi possível executar o arquivo IMAP da ZS Angola.');
        return $Self->ExitCodeError();
    }
    $Self->Print("Mensagens arquivadas: $Moved\n");
    return $Self->ExitCodeOk();
}

1;
