package Kernel::System::BWBEmailVerify;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::CheckItem',
    'Kernel::System::Log',
);

use constant {
    CACHE_TYPE  => 'BWBEmailVerify',
    RESULT_TTL  => 120,
    RATE_TTL    => 60,
    RATE_MAX    => 10,
    SMTP_BUDGET => 8,
    MX_LIMIT    => 2,
};

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Check {
    my ( $Self, %Param ) = @_;

    my $Email = $Self->_Normalize( $Param{Email} );
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Campo vazio.',
        Message   => 'Escreva um endereço de e-mail no campo e volte a clicar em Verificar.',
    ) if !$Email;

    my $UserID = $Param{UserID} ? int( $Param{UserID} ) : 0;
    if ( !$Self->_RateAllow( UserID => $UserID ) ) {
        return $Self->_Pack(
            Status    => 'limited',
            Technical => 'Limite de verificações (10 por minuto).',
            Message   => 'Fez demasiadas verificações seguidas. Espere um minuto e tente de novo.',
        );
    }

    my $Cached = $Self->_ResultGet($Email);
    return $Cached if $Cached;

    my $Result = $Self->_CheckFresh( Email => $Email );
    $Self->_ResultSet( $Email, $Result );
    return $Result;
}

sub _CheckFresh {
    my ( $Self, %Param ) = @_;
    my $Email = $Param{Email};

    my $CheckItem = $Kernel::OM->Get('Kernel::System::CheckItem');
    if ( !$CheckItem->CheckEmail( Address => $Email ) ) {
        return $Self->_CheckItemResult($CheckItem);
    }

    my ($Domain) = $Email =~ /\@([^@]+)\z/;
    $Domain = lc( $Domain // '' );
    $Domain =~ s/\s+//g;
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Domínio em falta ou inválido.',
        Message   => 'O texto à direita do @ não é um domínio de correio reconhecível. Corrija o endereço.',
    ) if !$Domain;

    my @MX = $Self->_MXHosts($Domain);
    return $Self->_Pack(
        Status    => 'inconclusive',
        Technical => 'Sem registo MX (DNS).',
        Message   => 'Não foi possível encontrar o servidor de correio deste domínio. Confirme se o endereço está bem escrito.',
    ) if !@MX;

    my $From     = $Self->_EnvelopeFrom();
    my $Hello    = $Self->_HelloName();
    my $Deadline = time() + SMTP_BUDGET;
    my $Last     = $Self->_Pack(
        Status    => 'inconclusive',
        Technical => 'Sem resposta SMTP utilizável.',
        Message   => 'Não foi possível confirmar este endereço. Tente de novo daqui a pouco.',
    );

    for my $Host (@MX) {
        my $Left = $Deadline - time();
        last if $Left < 2;
        my $Probe = $Self->_ProbeSMTP(
            Host    => $Host,
            Email   => $Email,
            From    => $From,
            Hello   => $Hello,
            Timeout => $Left,
        );
        return $Probe if $Probe->{Status} eq 'valid' || $Probe->{Status} eq 'invalid';
        $Last = $Probe;
    }

    return $Last;
}

sub _ProbeSMTP {
    my ( $Self, %Param ) = @_;

    my $Timeout = $Param{Timeout} && $Param{Timeout} > 1 ? int( $Param{Timeout} ) : 2;
    $Timeout = SMTP_BUDGET if $Timeout > SMTP_BUDGET;

    my $SMTP;
    my $Ok = eval {
        require Net::SMTP;
        $SMTP = Net::SMTP->new(
            $Param{Host},
            Port    => 25,
            Timeout => $Timeout,
            Hello   => $Param{Hello},
        );
        1;
    };
    if ( !$Ok || !$SMTP ) {
        return $Self->_Pack(
            Status    => 'inconclusive',
            Technical => 'Falha de ligação SMTP (porta 25 / tempo esgotado).',
            Message   => 'O sistema não conseguiu falar com o servidor de correio deste endereço. Tente mais tarde.',
        );
    }

    my $Finish = sub {
        my ($Result) = @_;
        eval { $SMTP->quit() };
        return $Result;
    };

    if ( $SMTP->can('starttls') && eval { $SMTP->supports('STARTTLS') } ) {
        my $TLS = eval { $SMTP->starttls() };
        if ( !$TLS ) {
            return $Finish->(
                $Self->_Pack(
                    Status    => 'inconclusive',
                    Technical => 'STARTTLS falhou.',
                    Message   => 'O servidor de correio exige uma ligação segura e essa ligação não foi possível. Tente mais tarde.',
                )
            );
        }
    }

    my $Mailed = eval { $SMTP->mail( $Param{From} ) };
    if ( !$Mailed ) {
        return $Finish->( $Self->_SMTPResult( SMTP => $SMTP, Status => 'inconclusive' ) );
    }

    my $Accepted = eval { $SMTP->to( $Param{Email} ) };
    my $Code     = 0;
    eval { $Code = int( $SMTP->code() || 0 ) };

    if ( $Accepted && ( $Code == 0 || $Code == 250 || $Code == 251 || $Code == 252 || $Code == 552 ) ) {
        return $Finish->( $Self->_SMTPResult( SMTP => $SMTP, Code => $Code, Status => 'valid' ) );
    }
    if ( $Code == 550 || $Code == 551 || $Code == 553 ) {
        return $Finish->( $Self->_SMTPResult( SMTP => $SMTP, Code => $Code, Status => 'invalid' ) );
    }
    if ( $Code == 450 || $Code == 451 || $Code == 452 || $Code == 421 ) {
        return $Finish->( $Self->_SMTPResult( SMTP => $SMTP, Code => $Code, Status => 'inconclusive' ) );
    }

    return $Finish->( $Self->_SMTPResult( SMTP => $SMTP, Code => $Code, Status => 'inconclusive' ) );
}

sub _SMTPResult {
    my ( $Self, %Param ) = @_;
    my $Raw       = $Self->_SMTPRaw( $Param{SMTP} );
    my $Code      = int( $Param{Code} || 0 );
    eval { $Code ||= int( $Param{SMTP}->code() || 0 ) };
    my $Enhanced  = '';
    $Enhanced = $1 if $Raw =~ /(\d\.\d\.\d)/;
    my $Status    = $Param{Status} || 'inconclusive';
    my $Technical = $Self->_SMTPTechnical(
        Code     => $Code,
        Enhanced => $Enhanced,
        Raw      => $Raw,
        Status   => $Status,
    );
    return $Self->_Pack(
        Status    => $Status,
        Technical => $Technical,
        Message   => $Self->_SMTPLay( Status => $Status, Enhanced => $Enhanced, Code => $Code ),
    );
}

sub _SMTPRaw {
    my ( $Self, $SMTP ) = @_;
    my $Text = '';
    eval {
        my $Raw = $SMTP->message();
        $Raw = join( ' ', @$Raw ) if ref $Raw eq 'ARRAY';
        $Text = $Raw // '';
        1;
    };
    $Text =~ s/\s+/ /g;
    $Text =~ s/\A\s+|\s+\z//g;
    return $Text;
}

sub _SMTPTechnical {
    my ( $Self, %Param ) = @_;
    my $Code     = int( $Param{Code} || 0 );
    my $Enhanced = $Param{Enhanced} || '';
    my $Prefix   = $Code ? $Code : '';
    $Prefix .= " $Enhanced" if $Enhanced;
    $Prefix =~ s/\A\s+|\s+\z//g;

    my $Meaning
        = $Enhanced eq '5.1.1' || $Enhanced eq '5.1.10' ? 'A conta de e-mail não existe.'
        : $Enhanced eq '5.1.2'                          ? 'O domínio de correio não aceita este destinatário.'
        : $Enhanced eq '5.1.3'                          ? 'O endereço tem uma sintaxe incorrecta para o servidor.'
        : $Enhanced eq '5.2.2' || $Param{Code} == 552   ? 'A caixa de correio está cheia.'
        : $Enhanced eq '5.7.1'                          ? 'O servidor recusou o destinatário por política de segurança.'
        : $Enhanced eq '4.2.1' || $Enhanced eq '4.7.1'  ? 'O servidor adiou a aceitação (greylist / limite).'
        : $Enhanced eq '2.1.5' || $Param{Code} == 250   ? 'O servidor aceitou o destinatário (RCPT TO).'
        : $Enhanced eq '2.1.0'                          ? 'O servidor aceitou o remetente (MAIL FROM).'
        : $Param{Status} eq 'invalid'                   ? 'O servidor recusou o destinatário.'
        : $Param{Status} eq 'valid'                     ? 'O servidor aceitou o destinatário (RCPT TO).'
        :                                                 'O servidor não confirmou o destinatário.';

    return $Prefix ? "$Prefix — $Meaning" : $Meaning;
}

sub _SMTPLay {
    my ( $Self, %Param ) = @_;
    my $Enhanced = $Param{Enhanced} || '';
    return 'Ninguém vai receber mensagens neste endereço. Corrija o e-mail na ficha antes de enviar ao cliente.'
        if $Enhanced eq '5.1.1' || $Enhanced eq '5.1.10' || $Param{Code} == 551;
    return 'A caixa existe, mas está cheia. O destinatário tem de libertar espaço antes de receber correio.'
        if $Enhanced eq '5.2.2' || $Param{Code} == 552;
    return 'O servidor recusou este endereço por regras próprias. Confirme o e-mail com o cliente.'
        if $Enhanced eq '5.7.1';
    return 'O servidor pediu para tentar mais tarde. Volte a verificar daqui a pouco.'
        if $Param{Status} eq 'inconclusive';
    return
        'Este endereço parece existir. Alguns fornecedores aceitam tudo e só depois recusam a entrega; neste caso o servidor aceitou-o.'
        if $Param{Status} eq 'valid';
    return 'Este endereço foi recusado. Corrija o e-mail na ficha antes de enviar ao cliente.';
}

sub _CheckItemResult {
    my ( $Self, $CheckItem ) = @_;
    my $Type = $CheckItem->CheckErrorType() || '';
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Sintaxe inválida.',
        Message   => 'O texto não tem o formato de um e-mail (nome@domínio). Corrija o endereço.',
    ) if $Type =~ /Syntax/i;
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Falha MX.',
        Message   => 'O domínio não tem servidor de correio configurado. Confirme se o endereço está certo.',
    ) if $Type =~ /MX/i;
    return $Self->_Pack(
        Status    => 'inconclusive',
        Technical => 'Falha DNS.',
        Message   => 'Não foi possível consultar o domínio neste momento. Tente de novo daqui a pouco.',
    ) if $Type =~ /DNS/i;
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Endereço recusado pela configuração.',
        Message   => 'Este endereço não é permitido neste sistema. Use outro e-mail.',
    ) if $Type =~ /Config/i;
    return $Self->_Pack(
        Status    => 'invalid',
        Technical => 'Endereço inválido.',
        Message   => 'Este endereço de e-mail não é válido. Corrija-o na ficha.',
    );
}

sub _Pack {
    my ( $Self, %Param ) = @_;
    return {
        Status    => $Param{Status}    || 'inconclusive',
        Technical => $Param{Technical} || '',
        Message   => $Param{Message}   || '',
    };
}

sub _MXHosts {
    my ( $Self, $Domain ) = @_;
    my @Hosts;

    eval {
        require Net::DNS;
        my $Resolver = Net::DNS::Resolver->new();
        $Resolver->udp_timeout(3);
        $Resolver->tcp_timeout(3);
        my $Nameserver = $Kernel::OM->Get('Kernel::Config')->Get('CheckMXRecord::Nameserver');
        $Resolver->nameservers($Nameserver) if $Nameserver;
        my $Packet = $Resolver->query( $Domain, 'MX' );
        return 1 if !$Packet;
        my @MX = grep { $_->type eq 'MX' } $Packet->answer;
        @MX = sort { $a->preference <=> $b->preference } @MX;
        for my $RR (@MX) {
            my $Host = $RR->exchange // '';
            $Host =~ s/\.\z//;
            push @Hosts, $Host if $Host;
        }
        1;
    };

    if ( !@Hosts ) {
        my $Packed = gethostbyname($Domain);
        push @Hosts, $Domain if $Packed;
    }

    my %Seen;
    my @Unique;
    for my $Host (@Hosts) {
        my $Key = lc $Host;
        next if $Seen{$Key}++;
        push @Unique, $Host;
        last if @Unique >= MX_LIMIT;
    }
    return @Unique;
}

sub _EnvelopeFrom {
    my ($Self) = @_;
    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $From   = $Config->Get('NotificationSenderEmail') || $Config->Get('AdminEmail') || '';
    if ( $From =~ /<([^>]+)>/ ) {
        $From = $1;
    }
    $From =~ s/\s+//g;
    return $From if $From =~ /\@/;

    my $FQDN = $Self->_HelloName();
    return "noreply\@$FQDN";
}

sub _HelloName {
    my ($Self) = @_;
    my $FQDN = $Kernel::OM->Get('Kernel::Config')->Get('FQDN') || 'localhost';
    $FQDN =~ s/:\d+\z//;
    $FQDN =~ s/\s+//g;
    return $FQDN || 'localhost';
}

sub _Normalize {
    my ( $Self, $Email ) = @_;
    $Email //= '';
    $Email =~ s/\A\s+|\s+\z//g;
    if ( $Email =~ /<([^>]+)>/ ) {
        $Email = $1;
    }
    $Email = lc $Email;
    $Email =~ s/\s+//g;
    return $Email;
}

sub _RateAllow {
    my ( $Self, %Param ) = @_;
    my $UserID = $Param{UserID} || 0;
    return 0 if !$UserID;

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache');
    my $Key   = 'rate:' . $UserID;
    my $Count = $Cache->Get(
        Type => CACHE_TYPE,
        Key  => $Key,
    ) || 0;
    $Count = int($Count);
    return 0 if $Count >= RATE_MAX;
    $Cache->Set(
        Type  => CACHE_TYPE,
        Key   => $Key,
        Value => $Count + 1,
        TTL   => RATE_TTL,
    );
    return 1;
}

sub _ResultGet {
    my ( $Self, $Email ) = @_;
    my $Value = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => CACHE_TYPE,
        Key  => 'result:v2:' . $Email,
    );
    return if !$Value || ref $Value ne 'HASH' || !$Value->{Status};
    return { %{$Value} };
}

sub _ResultSet {
    my ( $Self, $Email, $Result ) = @_;
    return if !$Result || ref $Result ne 'HASH';
    return if ( $Result->{Status} || '' ) eq 'limited';
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => CACHE_TYPE,
        Key   => 'result:v2:' . $Email,
        Value => { %{$Result} },
        TTL   => RESULT_TTL,
    );
    return 1;
}

1;
