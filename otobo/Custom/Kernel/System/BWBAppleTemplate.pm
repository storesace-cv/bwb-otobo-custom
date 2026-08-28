# --
# Simplificação HTML do modelo mod-apple-01 / bwb-answer-card.
# Preserva conteúdo textual comunicado; remove wrappers CKEditor e CSS problemático.
# --

package Kernel::System::BWBAppleTemplate;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);
use Encode qw(encode_utf8);
use HTML::Entities qw(decode_entities);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless $Self, $Type;
    return $Self;
}

sub MarkerComment { return '<!-- bwb-apple-v2 -->' }

sub AppleOccurrenceCount {
    my ( $Self, $HTML ) = @_;
    return 0 if !defined $HTML || $HTML eq '';
    my $Count = 0;
    $Count++ while $HTML =~ /apple-style-body|bwb-answer-card/g;
    return $Count;
}

sub IsAlreadyMigrated {
    my ( $Self, $HTML ) = @_;
    return 0 if !defined $HTML || $HTML eq '';
    return 0 if $HTML =~ /apple-style-body/;
    return 0 if $HTML !~ /bwb-answer-card/;
    return 0 if $HTML !~ /Helpdesk StoresAce/i;
    return 1 if $HTML =~ /<!--\s*bwb-apple-v2\s*-->/;
    return 0;
}

sub IsAppleCandidate {
    my ( $Self, $HTML ) = @_;
    return 0 if !defined $HTML || $HTML eq '';
    return 1 if $HTML =~ /apple-style-body/;
    if ( $HTML =~ /bwb-answer-card/ && $HTML =~ /Resumo da ocorr[eê]ncia/i && $HTML =~ /Helpdesk StoresAce/i ) {
        return 1;
    }
    return 0;
}

sub ClassifyHTML {
    my ( $Self, $HTML, $Size ) = @_;
    $Size ||= length( $HTML // '' );
    my $Hits = $Self->AppleOccurrenceCount($HTML);

    if ( $Self->IsAlreadyMigrated($HTML) ) {
        return 'already_migrated';
    }
    if ( !$Self->IsAppleCandidate($HTML) ) {
        return 'not_apple';
    }
    if ( $Hits >= 2 ) {
        return 'C_multi_quote';
    }
    if ( $Size > 25000 ) {
        return 'B_single_quote_large';
    }
    if ( $Size >= 15000 && $Size <= 25000 ) {
        return 'A_direct';
    }
    if ( $Hits >= 1 ) {
        return 'D_other_apple';
    }
    return 'D_other_apple';
}

sub NormalizeCommunicatedText {
    my ( $Self, $HTML ) = @_;
    return '' if !defined $HTML || $HTML eq '';

    my $Text = $HTML;

    # Marcador de migração não faz parte do conteúdo comunicado.
    $Text =~ s/<!--\s*bwb-apple-v2\s*-->//g;

    # Blocos CSS não têm texto comunicado.
    $Text =~ s/<style\b[^>]*>.*?<\/style>//gis;

    # URLs visíveis e destinos de links.
    my @URLs;
    while ( $Text =~ /<a\b[^>]*\href\s*=\s*(["'])(.*?)\1/gis ) {
        my $URL = $2;
        $URL =~ s/&amp;/&/g;
        push @URLs, $URL if length $URL;
    }

    $Text =~ s/<br\s*\/?>/\n/gi;
    $Text =~ s/<\/p>/\n/gi;
    $Text =~ s/<\/tr>/\n/gi;
    $Text =~ s/<\/li>/\n/gi;
    $Text =~ s/<[^>]+>//g;

    $Text = decode_entities($Text);

    # Normalizar NBSP e espaços sem alterar sequências alfanuméricas.
    $Text =~ s/\x{00A0}/ /g;
    $Text =~ s/[ \t]+/ /g;
    $Text =~ s/\n[ \t]+/\n/g;
    $Text =~ s/[ \t]+\n/\n/g;
    $Text =~ s/\n{3,}/\n\n/g;
    $Text =~ s/^\s+|\s+$//g;

    if (@URLs) {
        $Text .= "\n__URLS__\n" . join( "\n", sort @URLs );
    }

    return $Text;
}

sub SimplifyHTML {
    my ( $Self, $HTML ) = @_;
    return $HTML if !defined $HTML || $HTML eq '';

    if ( $Self->IsAlreadyMigrated($HTML) ) {
        return $HTML;
    }

    my $Out = $HTML;

    # Remover blocos <style> (globais ou Apple).
    $Out =~ s/<style\b[^>]*>.*?<\/style>//gis;

    # Desembrulhar <figure> CKEditor (preserva conteúdo interno).
    $Out =~ s/<figure\b[^>]*>//gi;
    $Out =~ s/<\/figure>//gi;

    # Renomear marcador principal e limpar classes Apple legadas.
    $Out =~ s/class=(["'])([^"']*)\bapple-style-body\b([^"']*)\1/"class=$1$2bwb-answer-card$3$1/gi;
    $Out =~ s/\bapple-style-(?:shell|card|brand|copy|foot)\b//g;
    $Out =~ s/\sclass=(["'])\s*\1//gi;

    # Remover !important dos estilos inline.
    $Out =~ s/!important\s*//gi;

    # Remover atributos de layout CKEditor sem valor semântico.
    $Out =~ s/\sborder-width:0px;?//gi;

    # Inserir marcador de migração uma vez no início.
    if ( $Out =~ /bwb-answer-card/ && $Out !~ /<!--\s*bwb-apple-v2\s*-->/ ) {
        $Out =~ s/^\s*/$Self->MarkerComment() . "\n"/e;
    }

    # Colapsar linhas em branco excessivas no markup (sem tocar em &nbsp; dentro de tags).
    $Out =~ s/\n{4,}/\n\n/g;

    return $Out;
}

sub TransformWithValidation {
    my ( $Self, $HTML ) = @_;

    my $Class = $Self->ClassifyHTML( $HTML, length( $HTML // '' ) );

    if ( $Class eq 'already_migrated' ) {
        return {
            Changed       => 0,
            Class         => $Class,
            SkipReason    => 'already_migrated',
            TextOK        => 1,
            HTML          => $HTML,
            AppleHits     => $Self->AppleOccurrenceCount($HTML),
            TextBefore    => $Self->NormalizeCommunicatedText($HTML),
            TextAfter     => $Self->NormalizeCommunicatedText($HTML),
        };
    }

    if ( $Class eq 'not_apple' ) {
        return {
            Changed       => 0,
            Class         => $Class,
            SkipReason    => 'not_apple',
            TextOK        => 1,
            HTML          => $HTML,
            AppleHits     => 0,
            TextBefore    => $Self->NormalizeCommunicatedText($HTML),
            TextAfter     => $Self->NormalizeCommunicatedText($HTML),
        };
    }

    my $TextBefore = $Self->NormalizeCommunicatedText($HTML);
    my $NewHTML    = $Self->SimplifyHTML($HTML);
    my $TextAfter  = $Self->NormalizeCommunicatedText($NewHTML);
    my $TextOK     = ( $TextBefore eq $TextAfter ) ? 1 : 0;

    return {
        Changed    => ( $NewHTML ne $HTML ) ? 1 : 0,
        Class      => $Class,
        SkipReason => $TextOK ? '' : 'text_mismatch',
        TextOK     => $TextOK,
        HTML       => $NewHTML,
        AppleHits  => $Self->AppleOccurrenceCount($HTML),
        TextBefore => $TextBefore,
        TextAfter  => $TextAfter,
    };
}

sub ContentSHA256 {
    my ( $Self, $Content ) = @_;
    my $Bytes = encode_utf8( $Content // '' );
    return sha256_hex($Bytes);
}

sub ListCandidates {
    my ( $Self, %Param ) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    $DBObject->Prepare(
        SQL => '
            SELECT att.id, att.article_id, art.ticket_id, att.content_size, att.content_type, att.content
            FROM article_data_mime_attachment att
            JOIN article art ON art.id = att.article_id
            WHERE att.content_type LIKE \'text/html%\'
              AND (
                CONVERT(att.content USING utf8mb4) LIKE \'%apple-style-body%\'
                OR CONVERT(att.content USING utf8mb4) LIKE \'%bwb-answer-card%\'
              )
            ORDER BY att.id',
    );

    my @Rows;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my ( $FileID, $ArticleID, $TicketID, $ContentSize, $ContentType, $Content ) = @Row;

        next if !defined $Content || $Content eq '';

        my $HTML = $EncodeObject->Convert(
            Text  => $Content,
            From  => 'utf-8',
            To    => 'utf-8',
            Check => 1,
        );

        my $Result = $Self->TransformWithValidation($HTML);

        next if $Result->{Class} eq 'not_apple';

        push @Rows, {
            FileID       => $FileID,
            ArticleID    => $ArticleID,
            TicketID     => $TicketID,
            ContentSize  => $ContentSize,
            ContentType  => $ContentType,
            Class        => $Result->{Class},
            AppleHits    => $Result->{AppleHits},
            BytesBefore  => length($HTML),
            BytesAfter   => length( $Result->{HTML} ),
            SHA256Before => $Self->ContentSHA256($HTML),
            SHA256After  => $Self->ContentSHA256( $Result->{HTML} ),
            TextOK       => $Result->{TextOK} ? 1 : 0,
            Changed      => $Result->{Changed} ? 1 : 0,
            SkipReason   => $Result->{SkipReason} // '',
            HTMLBefore   => $HTML,
            HTMLAfter    => $Result->{HTML},
        };
    }

    return @Rows;
}

sub ExecuteMigration {
    my ( $Self, %Param ) = @_;

    my $DryRun   = $Param{DryRun} ? 1 : 0;
    my $UserID   = $Param{UserID} || 1;
    my $Callback = $Param{Callback};

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my @Candidates = $Self->ListCandidates();

    my %Stats = (
        Found    => scalar @Candidates,
        Migrated => 0,
        Skipped  => 0,
        Errors   => 0,
    );

    CANDIDATE:
    for my $Row (@Candidates) {
        if ( $Row->{Class} eq 'already_migrated' && !$Row->{Changed} ) {
            $Stats{Skipped}++;
            $Callback->( $Row, 'skip' ) if $Callback;
            next CANDIDATE;
        }

        if ( !$Row->{TextOK} ) {
            $Stats{Errors}++;
            $Callback->( $Row, 'error' ) if $Callback;
            next CANDIDATE;
        }

        if ( !$Row->{Changed} ) {
            $Stats{Skipped}++;
            $Callback->( $Row, 'skip' ) if $Callback;
            next CANDIDATE;
        }

        if ($DryRun) {
            $Stats{Migrated}++;
            $Callback->( $Row, 'dry-run' ) if $Callback;
            next CANDIDATE;
        }

        my $NewContent = $Row->{HTMLAfter};
        my $NewSize    = length($NewContent);

        eval {
            $DBObject->Do(
                SQL  => '
                    UPDATE article_data_mime_attachment
                    SET content = ?, content_size = ?, change_time = current_timestamp, change_by = ?
                    WHERE id = ?',
                Bind => [
                    \$NewContent,
                    \$NewSize,
                    \$UserID,
                    \$Row->{FileID},
                ],
            );
            1;
        } or do {
            $LogObject->Log(
                Priority => 'error',
                Message  => "AppleTemplateMigrate: falha file_id=$Row->{FileID}: $@",
            );
            $Stats{Errors}++;
            $Callback->( $Row, 'error' ) if $Callback;
            next CANDIDATE;
        };

        $Stats{Migrated}++;
        $Callback->( $Row, 'migrated' ) if $Callback;
    }

    return \%Stats;
}

1;
