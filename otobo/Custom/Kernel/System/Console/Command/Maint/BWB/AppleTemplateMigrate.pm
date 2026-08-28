package Kernel::System::Console::Command::Maint::BWB::AppleTemplateMigrate;

use strict;
use warnings;
use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::BWBAppleTemplate',
);

sub Configure {
    my ($Self) = @_;

    $Self->Description(
        'Simplifica HTML histórico do modelo mod-apple-01 (remove figure/style/!important) preservando texto comunicado.'
    );
    $Self->AddOption(
        Name        => 'dry-run',
        Description => 'Listar candidatos e validação textual sem gravar.',
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'execute',
        Description => 'Aplicar transformação aprovada (requer backup prévio).',
        Required    => 0,
        HasValue    => 0,
    );
    return;
}

sub Run {
    my ($Self, %Param) = @_;

    my $DryRun  = $Self->GetOption('dry-run');
    my $Execute = $Self->GetOption('execute');

    if ( !$DryRun && !$Execute ) {
        $Self->PrintError('Indique --dry-run ou --execute.');
        return $Self->ExitCodeError();
    }
    if ( $DryRun && $Execute ) {
        $Self->PrintError('Use apenas uma opção: --dry-run ou --execute.');
        return $Self->ExitCodeError();
    }

    my $AppleObject = $Kernel::OM->Get('Kernel::System::BWBAppleTemplate');

    my $Stats = $AppleObject->ExecuteMigration(
        DryRun   => $DryRun ? 1 : 0,
        UserID   => 1,
        Callback => sub {
            my ( $Row, $Action ) = @_;
            $Self->_PrintRow( $Row, $Action );
        },
    );

    $Self->Print("\nResumo: encontrados=$Stats->{Found} migrados/dry-run=$Stats->{Migrated} "
        . "skipped=$Stats->{Skipped} erros=$Stats->{Errors}\n" );

    return $Stats->{Errors} ? $Self->ExitCodeError() : $Self->ExitCodeOk();
}

sub _PrintRow {
    my ( $Self, $Row, $Action ) = @_;

    my $TextOK = $Row->{TextOK} ? 'OK' : 'FAIL';
    $Self->Print(
        sprintf(
            "%s file_id=%s article_id=%s ticket_id=%s class=%s apple_hits=%s "
                . "bytes_before=%s bytes_after=%s sha256_before=%s sha256_after=%s text=%s skip=%s\n",
            $Action,
            $Row->{FileID},
            $Row->{ArticleID},
            $Row->{TicketID},
            $Row->{Class},
            $Row->{AppleHits},
            $Row->{BytesBefore},
            $Row->{BytesAfter},
            $Row->{SHA256Before},
            $Row->{SHA256After},
            $TextOK,
            $Row->{SkipReason} || '-',
        )
    );
    return;
}

1;
