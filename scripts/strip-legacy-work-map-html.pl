#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use DBI;

# Remove frame/pin Wikimedia antigos do HTML das folhas (anexo HTML).
# Uso: perl scripts/strip-legacy-work-map-html.pl   (com env DB ou defaults locais)

my $DSN  = $ENV{OTOBO_DB_DSN}  // 'DBI:mysql:database=otobo;host=127.0.0.1';
my $User = $ENV{OTOBO_DB_USER} // 'otobo';
my $Pass = $ENV{OTOBO_DB_PASS} // '';

my $dbh = DBI->connect( $DSN, $User, $Pass, { RaiseError => 1, mysql_enable_utf8mb4 => 1 } );

my $sth = $dbh->prepare(
    q{
        SELECT id, article_id, content
        FROM article_data_mime_attachment
        WHERE content_type LIKE 'text/html%'
          AND content LIKE '%Mapa da localização%'
          AND content LIKE '%maps.wikimedia.org%'
    }
);
$sth->execute();

my $upd = $dbh->prepare(
    q{UPDATE article_data_mime_attachment SET content = ? WHERE id = ?}
);

my $Count = 0;
while ( my ( $ID, $ArticleID, $HTML ) = $sth->fetchrow_array() ) {
    my $Orig = $HTML;

    # Título "Localização no fecho" / loja.
    $HTML =~ s{<div[^>]*>\s*Localização no fecho\s*</div>}{}gi;
    $HTML =~ s{<div[^>]*>\s*Localização \(coordenadas da loja\)\s*</div>}{}gi;

    # Bloco com img Wikimedia + pin CSS + coordenadas (mantém duração abaixo).
    $HTML =~ s{
        <div\s+style="margin:0\s+6px\s+28px;">
        .*?
        </div>(?=\s*<table\s+class="BWBAccountedDuration")
    }{}gsix;

    # Fallback: qualquer img do mapa legado.
    $HTML =~ s{
        <a[^>]*>\s*<span[^>]*>\s*
        <img[^>]*alt="Mapa da localização"[^>]*>
        .*?
        </span>\s*</a>
    }{}gsix;
    $HTML =~ s{<img[^>]*alt="Mapa da localização"[^>]*/?>}{}gi;
    $HTML =~ s{<span[^>]*rotate\(-45deg\)[^>]*>\s*</span>}{}gi;

    next if $HTML eq $Orig;
    $upd->execute( $HTML, $ID );
    $Count++;
    print "Artigo $ArticleID (attachment $ID) limpo.\n";
}

print "Total: $Count anexo(s).\n";
