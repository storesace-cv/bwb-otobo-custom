package Kernel::System::BWBZSSupervisorNotify;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBAccess',
    'Kernel::System::CustomerCompany',
    'Kernel::System::Email',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Notify {
    my ( $Self, %Param ) = @_;
    return if !$Param{TicketID} || !$Param{ActorUserID} || !$Param{Kind};

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    return if !$Access->IsZSCollaborator( UserID => $Param{ActorUserID} );

    # One e-mail per ticket per request (Field create + start work).
    return 1 if $Self->{Notified}->{ $Param{TicketID} };

    my $ResponsibleUserID = $Access->ZSResponsibleUserID();
    return if int( $Param{ActorUserID} ) == int($ResponsibleUserID);

    my %Responsible = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $ResponsibleUserID,
    );
    return if !$Responsible{UserEmail};

    my %Actor = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{ActorUserID},
    );
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;

    my $Customer = $Ticket{CustomerCompanyName} || $Ticket{CustomerName} || $Ticket{CustomerID} || '-';
    if ( $Ticket{CustomerID} && !$Ticket{CustomerCompanyName} ) {
        my %Company = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $Ticket{CustomerID},
        );
        $Customer = $Company{CustomerCompanyName} || $Customer;
    }

    my $HTMLUtils = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $Escape    = sub {
        return $HTMLUtils->ToHTML( String => defined $_[0] ? $_[0] : '' );
    };

    my $ActorName  = $Actor{UserFullname} || $Actor{UserLogin} || 'Colaborador';
    my $Kind       = $Param{Kind};
    my $Heading    = $Kind eq 'TicketCreate'
        ? 'Novo ticket da equipa ZS Angola'
        : 'Folha de trabalho iniciada';
    my $Intro      = $Kind eq 'TicketCreate'
        ? "$ActorName criou um ticket no âmbito ZS Angola."
        : "$ActorName iniciou uma folha de trabalho.";
    if ( $Kind eq 'TicketCreate' ) {
        $Intro .= ' Se o ticket foi aberto no modo de campo, a folha de trabalho fica associada de imediato.';
    }
    my $Subject = '[Ticket#' . ( $Ticket{TicketNumber} || '' ) . '] ' . $Heading;
    $Subject =~ s/[\r\n]+/ /g;

    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $Link   = ( $Config->Get('HttpType') || 'https' ) . '://'
        . ( $Config->Get('FQDN') || 'helpdesk.storesace.cv' )
        . '/otobo/index.pl?Action=AgentBWBWorkSession;TicketID='
        . $Param{TicketID};

    my $WorkTypeRow = '';
    if ( $Param{WorkType} ) {
        $WorkTypeRow = '<p><b>Tipo de intervenção:</b> ' . $Escape->( $Param{WorkType} ) . '</p>';
    }

    my $HTML = '<!doctype html><html><body style="margin:0;background:#f5f5f7">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f5f7"><tr><td style="padding:24px 12px">'
        . '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;margin:auto;background:#fff;border:1px solid #d2d2d7;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;color:#1d1d1f">'
        . '<tr><td style="padding:24px;background:#e5e5e7"><div style="font-size:13px;color:#6e6e73;margin-bottom:8px">Helpdesk - ZS Angola</div>'
        . '<h1 style="margin:0;font-size:22px;color:#1d1d1f">' . $Escape->($Heading) . '</h1></td></tr>'
        . '<tr><td style="padding:28px"><p>' . $Escape->($Intro) . '</p>'
        . '<p><b>Ticket:</b> ' . $Escape->( $Ticket{TicketNumber} ) . '<br>'
        . '<b>Cliente:</b> ' . $Escape->($Customer) . '<br>'
        . '<b>Título:</b> ' . $Escape->( $Ticket{Title} ) . '<br>'
        . '<b>Colaborador:</b> ' . $Escape->($ActorName) . '</p>'
        . $WorkTypeRow
        . '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:28px 0"><tr><td style="border-radius:7px;background:#3a3a3c">'
        . '<a href="' . $Escape->($Link) . '" style="display:inline-block;color:#fff;padding:14px 22px;text-decoration:none;font-weight:bold">Abrir a folha / ticket</a>'
        . '</td></tr></table></td></tr>'
        . '<tr><td style="padding:18px 28px;border-top:1px solid #d2d2d7;background:#f5f5f7;color:#6e6e73;font-size:12px">ZS Angola Digital, Lda.</td></tr>'
        . '</table></td></tr></table></body></html>';

    my $Sent = $Kernel::OM->Get('Kernel::System::Email')->Send(
        From     => 'Helpdesk - ZS Angola <assistencia@zsa-softwares.com>',
        ReplyTo  => 'Helpdesk - ZS Angola <assistencia@zsa-softwares.com>',
        To       => $Responsible{UserEmail},
        Subject  => $Subject,
        Charset  => 'utf-8',
        MimeType => 'text/html',
        Body     => $HTML,
    );
    if ( !$Sent || !$Sent->{Success} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "BWBZSSupervisorNotify: falha a notificar o responsável ZS do ticket $Param{TicketID}.",
        );
        return;
    }

    $Self->{Notified}->{ $Param{TicketID} } = $Kind;
    return 1;
}

1;
