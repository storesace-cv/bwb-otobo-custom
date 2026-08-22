package Kernel::System::BWBWorkSession;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(
    Kernel::System::DB Kernel::System::Ticket Kernel::System::Ticket::Article
    Kernel::System::User Kernel::System::DateTime Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend Kernel::System::Email Kernel::System::Queue
    Kernel::System::CustomerUser Kernel::System::Signature Kernel::System::Log
    Kernel::System::BWBZSSupervisorNotify Kernel::System::Main
    Kernel::System::BWBCustomerCompany Kernel::System::BWBTicketStore
    Kernel::System::BWBStore Kernel::System::HTMLUtils
);

sub new { my ($Type) = @_; return bless {}, $Type; }
sub LastError { return $_[0]->{LastError}; }

sub ActiveGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID};
    my $DB = $Kernel::OM->Get('Kernel::System::DB');

    # A ticket can be closed, removed or merged without the technician first
    # finishing the work sheet.  Such an orphan session must never block a new
    # work session.  Close it administratively without accounting billable
    # time, since no result/visibility decision was explicitly submitted.
    $DB->Do(
        SQL => q{
            UPDATE bwb_work_session s
            INNER JOIN ticket t ON t.id = s.ticket_id
            INNER JOIN ticket_state ts ON ts.id = t.ticket_state_id
            SET s.end_time = COALESCE(t.change_time, UTC_TIMESTAMP()),
                s.duration_minutes = 0,
                s.result = 'Sessão encerrada automaticamente: ticket terminado'
            WHERE s.user_id = ?
                AND s.end_time IS NULL
                AND ts.type_id IN (3, 6, 7)
        },
        Bind => [ \$Param{UserID} ],
    );

    $DB->Prepare(
        SQL  => 'SELECT id,ticket_id,user_id,work_type,start_time FROM bwb_work_session WHERE user_id=? AND end_time IS NULL ORDER BY id DESC LIMIT 1',
        Bind => [ \$Param{UserID} ],
    );
    my @Row = $DB->FetchrowArray();
    return @Row
        ? { SessionID => $Row[0], TicketID => $Row[1], UserID => $Row[2], WorkType => $Row[3], StartTime => $Row[4] }
        : undef;
}

sub OpenGetByTicket {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID};
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL  => 'SELECT id,ticket_id,user_id,work_type,start_time FROM bwb_work_session WHERE ticket_id=? AND end_time IS NULL ORDER BY id DESC LIMIT 1',
        Bind => [ \$Param{TicketID} ],
    );
    my @Row = $DB->FetchrowArray();
    return @Row
        ? { SessionID => $Row[0], TicketID => $Row[1], UserID => $Row[2], WorkType => $Row[3], StartTime => $Row[4] }
        : undef;
}

sub TransferToUser {
    my ( $Self, %Param ) = @_;
    return if !$Param{SessionID} || !$Param{NewUserID};
    my $Existing = $Self->ActiveGet( UserID => $Param{NewUserID} );
    return if $Existing && int( $Existing->{SessionID} ) != int( $Param{SessionID} );
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'UPDATE bwb_work_session SET user_id=? WHERE id=? AND end_time IS NULL',
        Bind => [ \$Param{NewUserID}, \$Param{SessionID} ],
    );
}

sub Start {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{TicketID} || $Self->ActiveGet( UserID => $Param{UserID} );
    my $OnTicket = $Self->OpenGetByTicket( TicketID => $Param{TicketID} );
    return if $OnTicket;
    return if !$Kernel::OM->Get('Kernel::System::Ticket')->TicketPermission(
        Type => 'rw', TicketID => $Param{TicketID}, UserID => $Param{UserID}, LogNo => 1,
    );
    my $Type = $Param{WorkType} || 'Assistência remota';
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Do(
        SQL  => 'INSERT INTO bwb_work_session(ticket_id,user_id,work_type,start_time,create_time) VALUES(?,?,?,UTC_TIMESTAMP(),UTC_TIMESTAMP())',
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Type ],
    );
    $Kernel::OM->Get('Kernel::System::BWBZSSupervisorNotify')->Notify(
        TicketID    => $Param{TicketID},
        ActorUserID => $Param{UserID},
        Kind        => 'WorkStart',
        WorkType    => $Type,
    );
    return 1 if $Param{NoArticle};
    my $Now = $Kernel::OM->Create('Kernel::System::DateTime')->Format( Format => '%d/%m/%Y às %H:%M' );
    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Param{UserID} );
    $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel( ChannelName => 'Internal' )->ArticleCreate(
        TicketID => $Param{TicketID}, SenderType => 'agent', Subject => 'Início da assistência técnica',
        Body => "Assistência técnica iniciada em $Now por $User{UserFullname}.\nTipo de intervenção: $Type.",
        From => $User{UserFullname}, ContentType => 'text/plain; charset=utf-8', HistoryType => 'AddNote',
        HistoryComment => 'Início de sessão de trabalho', IsVisibleForCustomer => 0, UserID => $Param{UserID},
    );
    return 1;
}

sub Finish {
    my ( $Self, %Param ) = @_;
    $Self->{LastError} = '';
    my $Active = $Self->ActiveGet( UserID => $Param{UserID} ) || do { $Self->{LastError} = 'Não existe uma sessão de trabalho ativa.'; return; };
    if ( $Param{TicketID} && $Active->{TicketID} != $Param{TicketID} ) { $Self->{LastError} = 'A sessão ativa pertence a outro ticket.'; return; }
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    $DB->Prepare(
        SQL => 'SELECT GREATEST(1,CEIL((TIMESTAMPDIFF(SECOND,s.start_time,UTC_TIMESTAMP())-COALESCE(w.paused_seconds,0)-CASE WHEN w.paused_at IS NULL THEN 0 ELSE TIMESTAMPDIFF(SECOND,w.paused_at,UTC_TIMESTAMP()) END)/60)),s.start_time,UTC_TIMESTAMP() FROM bwb_work_session s LEFT JOIN bwb_work_sheet w ON w.session_id=s.id WHERE s.id=?',
        Bind => [ \$Active->{SessionID} ],
    );
    my ( $Minutes, $StartUTC, $EndUTC ) = $DB->FetchrowArray();
    if (!$Minutes) { $Self->{LastError} = 'Não foi possível calcular a duração do trabalho.'; return; }
    my $StartObject = $Kernel::OM->Create('Kernel::System::DateTime', ObjectParams => { String => $StartUTC, TimeZone => 'UTC' } );
    my $EndObject   = $Kernel::OM->Create('Kernel::System::DateTime', ObjectParams => { String => $EndUTC, TimeZone => 'UTC' } );
    $StartObject->ToTimeZone( TimeZone => 'Europe/Lisbon' ); $EndObject->ToTimeZone( TimeZone => 'Europe/Lisbon' );
    my $Start = $StartObject->Format( Format => '%d/%m/%Y às %H:%M' );
    my $End   = $EndObject->Format( Format => '%d/%m/%Y às %H:%M' );
    my %User  = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Param{UserID} );
    my $Result = $Param{Result} || do { $Self->{LastError} = 'Selecione um resultado.'; return; };
    my %StateFor = (
        'Resolvido' => 'encerrado com êxito', 'Resolvido temporariamente' => 'open', 'Parcialmente resolvido' => 'open',
        'A aguardar confirmação do cliente' => 'Pendente a aguardar cliente', 'A aguardar informação do cliente' => 'Pendente a aguardar cliente',
        'A aguardar fornecedor' => 'Aguardar fornecedor', 'A aguardar intervenção presencial' => 'Pendente até determinada data',
        'Encaminhado para outro técnico' => 'open', 'Não resolvido' => 'open', 'Cancelado pelo cliente' => 'encerrado sem êxito',
        'Trabalho concluído — ticket mantém-se aberto' => 'open',
    );
    my $State = $StateFor{$Result};
    if ( $Result eq 'Sem anomalia detetada' ) { $State = $Param{Decision} && $Param{Decision} eq 'close' ? 'encerrado com êxito' : 'Pendente a aguardar cliente'; }
    elsif ( $Result eq 'Outro' ) { $State = $Param{State} || do { $Self->{LastError} = 'Selecione o estado seguinte do ticket.'; return; }; }
    if (!$State) { $Self->{LastError} = 'O resultado escolhido não tem um estado associado.'; return; }
    if ( $Result eq 'Encaminhado para outro técnico' && !$Param{NewOwnerID} ) { $Self->{LastError} = 'Selecione o novo proprietário do ticket.'; return; }
    if ( $Result eq 'A aguardar intervenção presencial' && !$Param{PendingDate} ) { $Self->{LastError} = 'Indique a data e a hora de retoma.'; return; }
    my $Ticket = $Kernel::OM->Get('Kernel::System::Ticket');
    if ( $Result eq 'Encaminhado para outro técnico' ) {
        return if !$Ticket->TicketOwnerSet( TicketID => $Active->{TicketID}, NewUserID => $Param{NewOwnerID}, UserID => $Param{UserID} );
    }
    if ( !$Ticket->TicketStateSet( TicketID => $Active->{TicketID}, State => $State, UserID => $Param{UserID} ) ) { $Self->{LastError} = 'Não foi possível aplicar o estado seguinte ao ticket.'; return; }
    if ( $Result eq 'A aguardar intervenção presencial' ) {
        my $Pending = $Param{PendingDate}; $Pending =~ s/T/ /; $Pending .= ':00' if $Pending =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/;
        if ( !$Ticket->TicketPendingTimeSet( String => $Pending, TicketID => $Active->{TicketID}, UserID => $Param{UserID} ) ) { $Self->{LastError} = 'Não foi possível gravar a data de retoma.'; return; }
    }
    my %StateLabel = ( open => 'Aberto', 'encerrado com êxito' => 'Encerrado com êxito', 'encerrado sem êxito' => 'Encerrado sem êxito' );
    my %TicketData = $Ticket->TicketGet( TicketID => $Active->{TicketID}, DynamicFields => 0, Silent => 1 );
    my $HelpdeskName = ( $TicketData{Queue} || '' ) =~ /^zs(?:angola)?-/i ? 'Helpdesk - ZS Angola' : 'Helpdesk - BWB';
    my $Notes = $Param{Observation} || '';

    my $StoreObject = $Kernel::OM->Get('Kernel::System::BWBStore');
    my $FinishLat = $StoreObject->_NormalizeCoord( $Param{FinishLatitude},  -90,  90 );
    my $FinishLon = $StoreObject->_NormalizeCoord( $Param{FinishLongitude}, -180, 180 );
    my $FinishAcc;
    if ( defined $Param{FinishAccuracy} && $Param{FinishAccuracy} ne '' ) {
        my $AccRaw = $Param{FinishAccuracy};
        $AccRaw =~ s/^\s+|\s+$//g;
        $AccRaw =~ s/,/./g;
        if ( $AccRaw =~ /^\d+(?:\.\d+)?$/ ) {
            $FinishAcc = sprintf( '%.2f', 0 + $AccRaw );
        }
    }
    my $LocationSource = '';
    my $LocationNote   = '';
    if (
        defined $FinishLat
        && defined $FinishLon
        && ( $Param{FinishLocationSource} || '' ) eq 'gps'
    )
    {
        $LocationSource = 'gps';
    }
    else {
        $FinishLat = undef;
        $FinishLon = undef;
        $FinishAcc = undef;
        my $TicketStore = $Kernel::OM->Get('Kernel::System::BWBTicketStore')->Get(
            TicketID => $Active->{TicketID},
        );
        my $StoreLat = $TicketStore
            ? $StoreObject->_NormalizeCoord( $TicketStore->{Latitude},  -90,  90 )
            : undef;
        my $StoreLon = $TicketStore
            ? $StoreObject->_NormalizeCoord( $TicketStore->{Longitude}, -180, 180 )
            : undef;
        if ( defined $StoreLat && defined $StoreLon ) {
            $FinishLat      = $StoreLat;
            $FinishLon      = $StoreLon;
            $LocationSource = 'store';
            $LocationNote
                = 'Localização GPS indisponível; usadas as coordenadas da loja associada ao ticket.';
        }
        else {
            $LocationSource = 'none';
            $LocationNote
                = 'Localização GPS indisponível e a loja associada não tem coordenadas registadas.';
        }
    }

    my $Font = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";
    my $Body = '<div style="font-family:'.$Font.';font-size:15px;line-height:1.5;color:#1d1d1f;max-width:760px;">';
    $Body .= '<div style="font-size:22px;font-weight:700;text-transform:uppercase;padding:0 4px 2px;border-bottom:1px solid #a1a1a6;margin-bottom:16px;">Folha de trabalho</div>';
    $Body .= '<table role="presentation" style="border-collapse:collapse;width:auto;max-width:100%;margin-bottom:42px;"><tbody>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:7px 8px 3px 12px;font-size:16px;white-space:nowrap;">Tipo de intervenção:</th><td style="padding:7px 12px 3px 8px;">'.$Active->{WorkType}.'</td></tr>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:3px 8px 3px 12px;font-size:16px;white-space:nowrap;">Técnico:</th><td style="padding:3px 12px 3px 8px;">'.$User{UserFullname}.'</td></tr>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:3px 8px 7px 12px;font-size:16px;white-space:nowrap;">Hora de início:</th><td style="padding:3px 12px 7px 8px;">'.$Start.'</td></tr>';
    $Body .= '</tbody></table>';
    if ( $Notes ne '' ) {
        $Body .= '<div style="display:inline-block;font-size:19px;font-weight:700;border-bottom:1px solid #1d1d1f;margin:0 0 18px 2px;">Notas:</div>';
        $Body .= '<div class="BWBWorkNotes" style="background:#eeeeef;border-radius:20px;padding:26px 24px;min-height:74px;margin:0 6px 48px;font-size:18px;line-height:1.55;">'.$Notes.'</div>';
    }
    else {
        $Body .= '<div style="display:inline-block;font-size:19px;font-weight:700;border-bottom:1px solid #1d1d1f;margin:0 0 18px 2px;">Notas:</div>';
        $Body .= '<div class="BWBWorkNotes" style="background:#eeeeef;border-radius:20px;padding:26px 24px;min-height:74px;margin:0 6px 48px;font-size:18px;line-height:1.55;color:#6e6e73;">Sem notas registadas.</div>';
    }
    $Body .= '<table role="presentation" style="border-collapse:collapse;width:auto;max-width:100%;margin-bottom:46px;"><tbody>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:7px 8px 3px 12px;font-size:16px;white-space:nowrap;">Hora do fim:</th><td style="padding:7px 12px 3px 8px;">'.$End.'</td></tr>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:3px 8px;font-size:16px;white-space:nowrap;">Resultado:</th><td style="padding:3px 12px 3px 8px;font-weight:400;">'.$Result.'</td></tr>';
    $Body .= '<tr><th style="background:#f2f2f2;text-align:right;padding:3px 8px 7px 12px;font-size:16px;white-space:nowrap;">Estado aplicado ao ticket:</th><td style="padding:3px 12px 7px 8px;font-weight:600;">'.($StateLabel{$State} || $State).'</td></tr>';
    $Body .= '</tbody></table>';
    if ( defined $FinishLat && defined $FinishLon ) {
        my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
        my $MapUrl
            = 'https://www.openstreetmap.org/?mlat='
            . $FinishLat
            . '&amp;mlon='
            . $FinishLon
            . '#map=17/'
            . $FinishLat . '/'
            . $FinishLon;
        my $CoordText = $FinishLat . ', ' . $FinishLon;
        $CoordText .= ' (±' . $FinishAcc . ' m)' if defined $FinishAcc && $LocationSource eq 'gps';
        # Dados para o mapa no AgentTicketZoom (secção separada). Sem frame/pin no HTML do artigo.
        $Body .= '<div class="BWBWorkLocation" style="display:none" aria-hidden="true" data-bwb-lat="'
            . $HTMLUtils->ToHTML( String => $FinishLat )
            . '" data-bwb-lon="'
            . $HTMLUtils->ToHTML( String => $FinishLon )
            . '" data-bwb-source="'
            . $HTMLUtils->ToHTML( String => $LocationSource )
            . '" data-bwb-coords="'
            . $HTMLUtils->ToHTML( String => $CoordText )
            . '" data-bwb-map-url="'
            . $MapUrl
            . '"'
            . (
            defined $FinishAcc
            ? ' data-bwb-acc="' . $HTMLUtils->ToHTML( String => $FinishAcc ) . '"'
            : ''
            )
            . (
            $LocationNote ne ''
            ? ' data-bwb-note="' . $HTMLUtils->ToHTML( String => $LocationNote ) . '"'
            : ''
            )
            . '></div>';
    }
    elsif ( $LocationNote ne '' ) {
        my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
        $Body
            .= '<div style="margin:0 6px 28px;font-size:14px;color:#6e6e73;">'
            . $HTMLUtils->ToHTML( String => $LocationNote )
            . '</div>';
    }
    $Body .= '<table class="BWBAccountedDuration" role="presentation" style="border-collapse:collapse;width:auto;max-width:100%;border-bottom:1px solid #a1a1a6;"><tbody><tr>';
    $Body .= '<th style="background:#f2f2f2;text-align:right;padding:9px 8px 9px 12px;font-size:16px;white-space:nowrap;">Duração contabilizada:</th><td style="padding:9px 12px 9px 8px;font-weight:400;">'.$Minutes.' minutos</td>';
    $Body .= '</tr></tbody></table></div>';
    my $ArticleID = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel( ChannelName => 'Internal' )->ArticleCreate(
        TicketID => $Active->{TicketID}, SenderType => 'agent', Subject => 'Folha de trabalho', Body => $Body,
        From => $HelpdeskName, ContentType => 'text/html; charset=utf-8', HistoryType => 'AddNote', HistoryComment => 'Folha de trabalho concluída',
        IsVisibleForCustomer => $Param{IsVisibleForCustomer} ? 1 : 0, Attachment => $Param{Attachment} || [], UserID => $Param{UserID},
    ) || do { $Self->{LastError} = 'Não foi possível criar o registo definitivo do trabalho.'; return; };
    if ( !$Ticket->TicketAccountTime( TicketID => $Active->{TicketID}, ArticleID => $ArticleID, TimeUnit => $Minutes, UserID => $Param{UserID} ) ) { $Self->{LastError} = 'Não foi possível contabilizar o tempo no ticket.'; return; }
    my $DF = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet( Name => 'UltimaIntervencao' );
    if ( $DF && $DF->{ID} ) { $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet( DynamicFieldConfig => $DF, ObjectID => $Active->{TicketID}, Value => $Result, UserID => $Param{UserID} ); }
    if (
        !$DB->Do(
            SQL => q{
                UPDATE bwb_work_session
                SET end_time=UTC_TIMESTAMP(), duration_minutes=?, result=?, observation=?,
                    finish_latitude=?, finish_longitude=?, finish_accuracy_m=?,
                    finish_location_source=?, finish_location_note=?, article_id=?
                WHERE id=?
            },
            Bind => [
                \$Minutes, \$Result, \$Notes,
                \$FinishLat, \$FinishLon, \$FinishAcc,
                \$LocationSource, \$LocationNote, \$ArticleID,
                \$Active->{SessionID},
            ],
        )
        )
    {
        $Self->{LastError} = 'Não foi possível encerrar a sessão de trabalho.';
        return;
    }
    if ( $Param{SendEmailToCustomer} ) {
        my %Customer = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $TicketData{CustomerUserID},
        );
        my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $TicketData{QueueID} );
        my %Address = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress( QueueID => $TicketData{QueueID} );
        my $Signature = '';
        if ( $Queue{SignatureID} ) {
            my %SignatureData = $Kernel::OM->Get('Kernel::System::Signature')->SignatureGet( ID => $Queue{SignatureID} );
            $Signature = $SignatureData{Text} || '';
        }
        my $Recipient = $Customer{UserEmail} || $TicketData{CustomerUserID} || '';
        my $MailSheet = $Kernel::OM->Get('Kernel::System::BWBCustomerCompany')->MaybeStripAccountedDuration(
            Content    => $Body,
            CustomerID => $TicketData{CustomerID},
            TicketID   => $Active->{TicketID},
        );
        my $MailBody = '<div style="font-family:'.$Font.';font-size:15px;line-height:1.5;color:#1d1d1f;max-width:760px;margin:auto;">'.$MailSheet;
        $MailBody .= '<div style="margin-top:32px;padding-top:20px;border-top:1px solid #d2d2d7;">'.$Signature.'</div>' if $Signature ne '';
        $MailBody .= '</div>';
        my $Subject = '[Ticket#'.($TicketData{TicketNumber} || '').'] Folha de trabalho: '.($TicketData{Title} || '');
        $Subject =~ s/[\r\n]+/ /g;
        my $Sent = $Recipient && $Address{Email} && $Kernel::OM->Get('Kernel::System::Email')->Send(
            From      => ($Address{RealName} || $HelpdeskName).' <'.$Address{Email}.'>',
            ReplyTo   => ($Address{RealName} || $HelpdeskName).' <'.$Address{Email}.'>',
            To        => $Recipient,
            Subject   => $Subject,
            Charset   => 'utf-8',
            MimeType  => 'text/html',
            Body      => $MailBody,
            ArticleID => $ArticleID,
            TicketID  => $Active->{TicketID},
            BWBSource => 'worksheet',
        );
        if ( !$Sent || !$Sent->{Success} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Não foi possível enviar por e-mail a folha de trabalho do ticket $Active->{TicketID} para $Recipient.",
            );
        }
        else {
            my $Header    = $Sent->{Data}->{Header} || '';
            my $MessageID = '';
            if ( $Header =~ /Message-ID:\s*(<[^>]+>)/i ) {
                $MessageID = $1;
            }
            elsif ( $Header =~ /Message-ID:\s*(\S+)/i ) {
                $MessageID = $1;
            }
            if ($MessageID) {
                my $MD5 = $Kernel::OM->Get('Kernel::System::Main')->MD5sum( String => $MessageID );
                $DB->Do(
                    SQL => 'UPDATE article_data_mime SET a_to=?, a_message_id=?, a_message_id_md5=? WHERE article_id=?',
                    Bind => [ \$Recipient, \$MessageID, \$MD5, \$ArticleID ],
                );
            }
            else {
                $DB->Do(
                    SQL  => 'UPDATE article_data_mime SET a_to=? WHERE article_id=?',
                    Bind => [ \$Recipient, \$ArticleID ],
                );
            }
        }
    }
    return $Minutes;
}
1;
