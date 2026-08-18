package Kernel::System::BWBBounceNotify;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBBounce',
    'Kernel::System::DB',
    'Kernel::System::Email',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Notify {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID} || !$Param{ArticleID};

    return 1 if $Self->{Notified}->{ $Param{ArticleID} };

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $Backend       = $ArticleObject->BackendForArticle(
        TicketID  => $Param{TicketID},
        ArticleID => $Param{ArticleID},
    );
    return if !$Backend;
    my %Article = $Backend->ArticleGet(
        TicketID  => $Param{TicketID},
        ArticleID => $Param{ArticleID},
        UserID    => 1,
    );
    return if !%Article;

    my $Bounce = $Kernel::OM->Get('Kernel::System::BWBBounce');
    return if !$Bounce->IsBounce(
        GetParam => {
            From           => $Article{From},
            Subject        => $Article{Subject},
            Body           => $Article{Body},
            'Content-Type' => $Article{ContentType},
        },
    );

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;

    my $Recipient = $Bounce->FailedRecipient(
        GetParam => {
            From    => $Article{From},
            Subject => $Article{Subject},
            Body    => $Article{Body},
        },
    ) || '-';

    my %AgentIDs;
    $AgentIDs{ $Ticket{OwnerID} } = 1 if $Ticket{OwnerID} && int( $Ticket{OwnerID} ) != 1;
    my $OriginalUserID = $Self->_OriginalSenderUserID(
        TicketID  => $Param{TicketID},
        Recipient => $Recipient,
    );
    $AgentIDs{$OriginalUserID} = 1 if $OriginalUserID && int($OriginalUserID) != 1;

    my $Access  = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my $Anchor  = ( $Ticket{OwnerID} && int( $Ticket{OwnerID} ) != 1 ) ? $Ticket{OwnerID} : $OriginalUserID;
    my $ResponsibleUserID = $Anchor ? $Access->ResponsibleUserIDGet( UserID => $Anchor ) : undef;
    $AgentIDs{$ResponsibleUserID} = 1 if $ResponsibleUserID && int($ResponsibleUserID) != 1;

    if ( $Param{OnlyUserIDs} && ref $Param{OnlyUserIDs} eq 'ARRAY' ) {
        my %Only = map { int($_) => 1 } grep { $_ } @{ $Param{OnlyUserIDs} };
        for my $UserID ( keys %AgentIDs ) {
            delete $AgentIDs{$UserID} if !$Only{$UserID};
        }
    }

    return 1 if !%AgentIDs;

    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my %Address     = $QueueObject->GetSystemAddress( QueueID => $Ticket{QueueID} );
    my $Helpdesk    = ( $Ticket{Queue} || '' ) =~ /^zs(?:angola)?-/i
        ? 'Helpdesk - ZS Angola'
        : 'Helpdesk - BWB';
    my $From = ( $Address{RealName} || $Helpdesk ) . ' <' . ( $Address{Email} || 'helpdesk@bwb.pt' ) . '>';

    my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $Escape    = sub {
        return $HTMLUtils->ToHTML( String => defined $_[0] ? $_[0] : '' );
    };
    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $Link   = ( $Config->Get('HttpType') || 'https' ) . '://'
        . ( $Config->Get('FQDN') || 'helpdesk.storesace.cv' )
        . '/otobo/index.pl?Action=AgentTicketZoom;TicketID='
        . $Param{TicketID};
    my $Subject = '[Ticket#' . ( $Ticket{TicketNumber} || '' ) . '] E-mail não entregue';
    $Subject =~ s/[\r\n]+/ /g;
    my $Error = $Article{Body} || '';
    $Error =~ s/\s+/ /g;
    $Error = substr( $Error, 0, 500 );

    my $HTML = '<!doctype html><html><body style="margin:0;background:#f5f5f7">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f5f7"><tr><td style="padding:24px 12px">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;margin:auto;background:#fff;border:1px solid #d2d2d7;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;color:#1d1d1f">'
        . '<tr><td style="padding:24px;background:#e5e5e7"><div style="font-size:13px;color:#6e6e73;margin-bottom:8px">'
        . $Escape->($Helpdesk)
        . '</div><h1 style="margin:0;font-size:22px;color:#1d1d1f">E-mail não entregue</h1></td></tr>'
        . '<tr><td style="padding:28px"><p>O sistema de correio devolveu uma mensagem enviada a partir deste ticket. O destinatário não recebeu o e-mail.</p>'
        . '<p><b>Ticket:</b> ' . $Escape->( $Ticket{TicketNumber} ) . '<br>'
        . '<b>Título:</b> ' . $Escape->( $Ticket{Title} ) . '<br>'
        . '<b>Endereço falhado:</b> ' . $Escape->($Recipient) . '</p>'
        . '<p style="color:#6e6e73;font-size:14px">' . $Escape->($Error) . '</p>'
        . '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:28px 0"><tr><td style="border-radius:7px;background:#3a3a3c">'
        . '<a href="' . $Escape->($Link) . '" style="display:inline-block;color:#fff;padding:14px 22px;text-decoration:none;font-weight:bold">Abrir o ticket</a>'
        . '</td></tr></table>'
        . '<p style="color:#6e6e73;font-size:13px">Confirme o endereço na ficha do utilizador de cliente. O cliente não recebeu este aviso.</p>'
        . '</td></tr></table></td></tr></table></body></html>';

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $Email      = $Kernel::OM->Get('Kernel::System::Email');
    my $SentAny;
    for my $UserID ( sort { $a <=> $b } keys %AgentIDs ) {
        my %User = $UserObject->GetUserData( UserID => $UserID );
        next if !$User{UserEmail};
        my $Sent = $Email->Send(
            From     => $From,
            ReplyTo  => $From,
            To       => $User{UserEmail},
            Subject  => $Subject,
            Charset  => 'utf-8',
            MimeType => 'text/html',
            Body     => $HTML,
            Loop     => 1,
        );
        if ( !$Sent || !$Sent->{Success} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "BWBBounceNotify: falha a avisar o utilizador $UserID do ticket $Param{TicketID}.",
            );
            next;
        }
        $SentAny = 1;
    }

    $Self->{Notified}->{ $Param{ArticleID} } = 1 if $SentAny;
    return $SentAny;
}

sub _OriginalSenderUserID {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID};
    my $Recipient = lc( $Param{Recipient} // '' );
    my $DB        = $Kernel::OM->Get('Kernel::System::DB');
    my $SQL       = q{
        SELECT a.create_by
        FROM article a
        INNER JOIN article_data_mime m ON m.article_id = a.id
        WHERE a.ticket_id = ?
          AND a.create_by != 1
          AND a.article_sender_type_id IN (1, 2)
    };
    my @Bind = ( \$Param{TicketID} );
    if ( $Recipient && $Recipient ne '-' ) {
        my $Like = '%' . $Recipient . '%';
        $SQL .= ' AND (LOWER(m.a_to) LIKE ? OR LOWER(m.a_cc) LIKE ?)';
        push @Bind, \$Like, \$Like;
    }
    $SQL .= ' ORDER BY a.id DESC LIMIT 1';
    return if !$DB->Prepare( SQL => $SQL, Bind => \@Bind );
    my ($UserID) = $DB->FetchrowArray();
    return $UserID;
}

1;
