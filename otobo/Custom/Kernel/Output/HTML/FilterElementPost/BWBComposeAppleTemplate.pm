# --
# Remove a saudação da fila que o Compose coloca acima do cartão mod-apple-01.
# O OTOBO 11 concatena Salutation + Template via Ticket::Frontend::ResponseFormat;
# o cartão já inclui a saudação. Não se altera a saudação das outras respostas.
# --

package Kernel::Output::HTML::FilterElementPost::BWBComposeAppleTemplate;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless $Self, $Type;
    $Self->{Action} = $Param{Action} || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Data};
    return 1 if $Self->{Action} && $Self->{Action} ne 'AgentTicketCompose';
    return 1 if ${ $Param{Data} } !~ /apple-style-body/;

    ${ $Param{Data} } =~ s{
        (<textarea\b[^>]*\bid="RichText"[^>]*>)
        (.*?)
        ((?:<figure|&lt;figure)[\s\S]{0,500}?apple-style-body)
    }{$1$3}xsi;

    return 1;
}

1;
