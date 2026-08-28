#!/usr/bin/env perl
# Métricas estruturais old vs new mod-apple-01 (offline, sem OTOBO).
use strict;
use warnings;
use utf8;

my $Root = (split /\n/, `git -C "$ENV{PWD}" rev-parse --show-toplevel 2>/dev/null`)[0]
    || do { my $b = $0; $b =~ s{/scripts/.*}{}; $b };

sub slurp {
    open my $fh, '<:utf8', $_[0] or die "$_[0]: $!";
    local $/; <$fh>;
}

sub metrics {
    my ($html) = @_;
    return {
        bytes     => length($html),
        tables    => scalar(() = $html =~ /<table/gi),
        figures   => scalar(() = $html =~ /<figure/gi),
        styles    => scalar(() = $html =~ /<style/gi),
        important => scalar(() = $html =~ /!important/gi),
        markers   => scalar(() = $html =~ /apple-style-body|bwb-answer-card/gi),
    };
}

my $legacy_sql = slurp("$Root/db/migrations/2026-08-21-mod-apple-01-espacamento-botao.sql");
my ($legacy) = $legacy_sql =~ /text = '(.*)',\s*\n\s*change_time/s;
die "legacy extract failed\n" if !defined $legacy;
$legacy =~ s/''/'/g;

my $new = slurp("$Root/otobo/Custom/Kernel/Output/HTML/Templates/Standard/BWBEmail/mod-apple-01.html");

print "=== Template v2 (novo) ===\n";
my $mn = metrics($new);
printf "bytes=%d tables=%d figures=%d styles=%d important=%d markers=%d\n",
    @$mn{qw(bytes tables figures styles important markers)};

print "\n=== Template legado (2026-08-21) ===\n";
my $mo = metrics($legacy);
printf "bytes=%d tables=%d figures=%d styles=%d important=%d markers=%d\n",
    @$mo{qw(bytes tables figures styles important markers)};

print "\n=== Crescimento simulado (6 citações) ===\n";
for my $pair ( [ 'legado', $legacy ], [ 'v2', $new ] ) {
    my ( $label, $seed ) = @$pair;
    my $body = $seed;
    for my $gen ( 1 .. 6 ) {
        $body = '<p>Resposta agente.</p><hr/>' . $body;
        my $m = metrics($body);
        printf "%s gen=%d bytes=%d tables=%d figures=%d markers=%d\n",
            $label, $gen, $m->{bytes}, $m->{tables}, $m->{figures}, $m->{markers};
    }
}

print "\nRedução estrutural v2 vs legado: "
    . int( (1 - $mn->{bytes} / $mo->{bytes} ) * 100 ) . "% bytes, "
    . "$mo->{figures} figures → $mn->{figures}, "
    . "$mo->{important} !important → $mn->{important}\n";
