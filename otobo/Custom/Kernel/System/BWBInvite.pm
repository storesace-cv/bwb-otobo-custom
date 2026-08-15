package Kernel::System::BWBInvite;
use strict;
use warnings;
use utf8;
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64url);
our @ObjectDependencies = qw(Kernel::System::DB Kernel::System::Email Kernel::System::User Kernel::System::CustomerUser Kernel::Config);
sub new { my($Type)=@_; return bless {},$Type }
sub CreateAndSend {
    my($Self,%P)=@_; return if !$P{Type} || !$P{Login} || !$P{Email};
    return 1 if $P{Email} =~ /\Atestes\@\d+\.com\z/i;
    my $Raw=encode_base64url(pack('H*',sha256_hex(join(':',rand(),time(),$$,$P{Login},{}))));
    my $Hash=sha256_hex($Raw); my $DB=$Kernel::OM->Get('Kernel::System::DB');
    $DB->Do(SQL=>'UPDATE bwb_invite SET used_time=current_timestamp WHERE account_type=? AND login=? AND used_time IS NULL',Bind=>[\$P{Type},\$P{Login}]);
    $DB->Do(SQL=>q{INSERT INTO bwb_invite(token_hash,account_type,login,email,expires_time,create_time,create_by) VALUES(?,?,?,?,DATE_ADD(current_timestamp,INTERVAL 48 HOUR),current_timestamp,?)},Bind=>[\$Hash,\$P{Type},\$P{Login},\$P{Email},\($P{UserID}||1)]) or return;
    my $Base=$Kernel::OM->Get('Kernel::Config')->Get('HttpType').'://'.$Kernel::OM->Get('Kernel::Config')->Get('FQDN').'/otobo/public.pl?Action=PublicBWBInvite;Token='.$Raw;
    my $Escape = sub { my $V=defined $_[0] ? $_[0] : ''; $V =~ s/&/&amp;/g; $V =~ s/</&lt;/g; $V =~ s/>/&gt;/g; $V =~ s/"/&quot;/g; return $V };
    my $Name=$Escape->($P{Name}); my $Login=$Escape->($P{Login}); my $Email=$Escape->($P{Email});
    my $Portal=$P{Type} eq 'customer' ? 'portal de cliente, onde poderá registar e acompanhar ocorrências, consultar o histórico e responder à equipa de suporte' : 'plataforma de agentes, onde poderá tratar pedidos e consultar os clientes que lhe forem atribuídos';
    my $Mode=$P{Mode}||'invite';
    my($Subject,$Heading,$Intro,$Button,$Closing);
    if($Mode eq 'password-reset'){
        $Subject='Reposição da palavra-passe | Plataforma de Suporte';
        $Heading='Repor a palavra-passe';
        $Intro='Recebemos um pedido para definir uma nova palavra-passe para a sua conta na nossa plataforma de suporte.';
        $Button='Definir nova palavra-passe';
        $Closing='Se não solicitou esta alteração, pode ignorar esta mensagem. A sua palavra-passe atual continuará válida enquanto esta ligação não for utilizada.';
    }
    else {
        $Subject='Convite para aceder à Plataforma de Suporte';
        $Heading='Bem-vindo à plataforma de suporte';
        $Intro='A sua conta encontra-se disponível na nossa plataforma de suporte. Convidamo-lo a ativar o acesso e a escolher a sua palavra-passe.';
        $Button='Aceder à Plataforma';
        $Closing='Depois de definir a palavra-passe, poderá entrar normalmente no portal sempre que necessitar.';
    }
    # Select the operational identity from the agent who initiated the action.
    # User 4 is the ZS Angola responsible agent; collaborators inherit that
    # identity through bwb_agent_hierarchy.
    my $ResponsibleUserID = $P{UserID} || 0;
    if ($ResponsibleUserID) {
        $DB->Prepare(
            SQL  => 'SELECT responsible_user_id FROM bwb_agent_hierarchy WHERE user_id = ?',
            Bind => [ \$ResponsibleUserID ],
        );
        my ($InheritedResponsibleUserID) = $DB->FetchrowArray();
        $ResponsibleUserID = $InheritedResponsibleUserID if $InheritedResponsibleUserID;
    }
    my $IsZS = $ResponsibleUserID == 4 ? 1 : 0;
    my $BrandName = $IsZS ? 'Plataforma de Suporte ZS Angola' : 'Plataforma de Suporte BWB';
    my $From      = $IsZS ? 'Plataforma de Suporte ZS Angola <assistencia@zsa-softwares.com>' : 'Plataforma de Suporte BWB <suporte@bwb.pt>';
    my $ReplyTo   = $IsZS ? 'Helpdesk - ZS Angola <assistencia@zsa-softwares.com>' : 'Helpdesk - BWB <helpdesk@bwb.pt>';
    my $Footer    = $IsZS ? 'ZS Angola Digital, Lda.' : 'Powered by BwB | © 2026 | jorge peixinho';
    my $HTML=qq{<!doctype html><html><body style="margin:0;background:#f5f5f7"><div style="display:none;max-height:0;overflow:hidden">$Subject</div><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f5f7"><tr><td style="padding:24px 12px"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;margin:auto;background:#fff;border:1px solid #d2d2d7;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;color:#1d1d1f"><tr><td style="padding:24px;background:#e5e5e7"><div style="font-size:13px;color:#6e6e73;margin-bottom:8px">$BrandName</div><h1 style="margin:0;font-size:24px;color:#1d1d1f">$Heading</h1></td></tr><tr><td style="padding:28px"><p>Olá $Name,</p><p>$Intro</p><p><b>Nome de utilizador:</b> $Login<br><b>Email associado:</b> $Email</p><p>Terá acesso ao $Portal.</p><table role="presentation" cellspacing="0" cellpadding="0" style="margin:28px 0"><tr><td style="border-radius:7px;background:#3a3a3c"><a href="$Base" style="display:inline-block;color:#fff;padding:14px 22px;text-decoration:none;font-weight:bold">$Button</a></td></tr></table><p>Esta ligação é pessoal, só pode ser utilizada uma vez e expira em 48 horas. Ao abri-la deverá escolher uma palavra-passe com pelo menos 8 caracteres, incluindo maiúscula, minúscula, número e símbolo.</p><p>$Closing</p></td></tr><tr><td style="padding:18px 28px;border-top:1px solid #d2d2d7;background:#f5f5f7;color:#6e6e73;font-size:12px">$Footer</td></tr></table></td></tr></table></body></html>};
    return $Kernel::OM->Get('Kernel::System::Email')->Send(
        From     => $From,
        ReplyTo  => $ReplyTo,
        To       => $P{Email},
        Subject  => $Subject,
        Charset  => 'utf-8',
        MimeType => 'text/html',
        Body     => $HTML,
    )->{Success};
}
sub Validate { my($Self,%P)=@_; return if !$P{Token}; my $H=sha256_hex($P{Token}); my $DB=$Kernel::OM->Get('Kernel::System::DB'); $DB->Prepare(SQL=>'SELECT account_type,login,email FROM bwb_invite WHERE token_hash=? AND used_time IS NULL AND expires_time>current_timestamp',Bind=>[\$H]); my @R=$DB->FetchrowArray(); return @R?{Type=>$R[0],Login=>$R[1],Email=>$R[2],Hash=>$H}:undef }
sub Consume { my($Self,%P)=@_; my $I=$Self->Validate(Token=>$P{Token}) or return; return if !$P{Password} || $P{Password}!~/\A(?=.{8,}\z)(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).*\z/s; my $OK=$I->{Type} eq 'customer' ? $Kernel::OM->Get('Kernel::System::CustomerUser')->SetPassword(UserLogin=>$I->{Login},PW=>$P{Password}) : $Kernel::OM->Get('Kernel::System::User')->SetPassword(UserLogin=>$I->{Login},PW=>$P{Password}); return if !$OK; $Kernel::OM->Get('Kernel::System::DB')->Do(SQL=>'UPDATE bwb_invite SET used_time=current_timestamp WHERE token_hash=?',Bind=>[\$I->{Hash}]); return $I }
1;
