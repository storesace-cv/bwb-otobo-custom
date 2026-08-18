package Kernel::System::BWBBounce;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBCustomerUserEmail',
    'Kernel::System::CheckItem',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub IsBounce {
    my ( $Self, %Param ) = @_;
    my $GetParam = $Param{GetParam} || {};
    return 1 if $GetParam->{'X-OTOBO-Bounce'};

    my $From = lc( $GetParam->{From} // '' );
    return 1 if $From =~ m{\b(?:mailer-daemon|postmaster|mail-daemon)\b}i;

    my $Subject = $GetParam->{Subject} // '';
    return 1 if $Subject =~ m{\b(?:delivery status notification|undelivered mail|returned mail|failure notice|mail delivery failed)\b}i;

    my $ContentType = $GetParam->{'Content-Type'} // '';
    return 1 if $ContentType =~ m{multipart/report}i && $ContentType =~ m{delivery-status}i;
    return 1 if $ContentType =~ m{message/delivery-status}i;

    return 0;
}

sub ApplyFollowUpHeaders {
    my ( $Self, %Param ) = @_;
    my $GetParam = $Param{GetParam} || return;
    $GetParam->{'X-OTOBO-FollowUp-State-Keep'} = 1;
    $GetParam->{'X-OTOBO-IsVisibleForCustomer'} = 0;
    $GetParam->{'X-OTOBO-SenderType'}           = 'system';
    $GetParam->{'X-OTOBO-Loop'}                 = 1;
    return 1;
}

sub OriginalMessageID {
    my ( $Self, %Param ) = @_;
    my $GetParam = $Param{GetParam} || {};
    my $MessageID = $GetParam->{'X-OTOBO-Bounce-OriginalMessageID'} // '';
    $MessageID =~ s/^\s+|\s+$//g;
    return $MessageID if $MessageID;
    return;
}

sub TicketIDByMessageID {
    my ( $Self, %Param ) = @_;
    my $MessageID = $Param{MessageID} || return;
    $MessageID =~ s/^\s+|\s+$//g;
    return if !$MessageID;

    my $Bare = $MessageID;
    $Bare =~ s/\A<|>\z//g;
    my $Bracketed = '<' . $Bare . '>';
    my $DB        = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => q{
            SELECT a.ticket_id
            FROM article_data_mime m
            INNER JOIN article a ON a.id = m.article_id
            WHERE m.a_message_id IN (?, ?, ?)
            ORDER BY a.id DESC
            LIMIT 1
        },
        Bind => [ \$MessageID, \$Bracketed, \$Bare ],
    );
    my ($TicketID) = $DB->FetchrowArray();
    return $TicketID;
}

sub FailedRecipient {
    my ( $Self, %Param ) = @_;
    my $GetParam = $Param{GetParam} || {};
    my $Parser   = $Param{ParserObject};
    my $Check    = $Kernel::OM->Get('Kernel::System::CheckItem');

    my @Candidates;
    my $Push = sub {
        my $Email = $_[0] // '';
        $Email =~ s/[<>]//g;
        $Email =~ s/^\s+|\s+$//g;
        $Email = lc $Email;
        return if !$Email || !$Check->CheckEmail( Address => $Email );
        return if $Email =~ m{\b(?:mailer-daemon|postmaster)\b}i;
        push @Candidates, $Email;
    };

    my $Body = $GetParam->{Body} // '';
    if ( $Body =~ m{failed permanently:.*?([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})}is ) {
        $Push->($1);
    }
    if ( $Body =~ m{recipient failed:.*?([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})}is ) {
        $Push->($1);
    }
    if ( $Body =~ m{Final-Recipient:\s*(?:rfc822;)?\s*<?([^>\s]+@[^>\s]+)}i ) {
        $Push->($1);
    }
    if ( $Body =~ m{Original-Recipient:\s*(?:rfc822;)?\s*<?([^>\s]+@[^>\s]+)}i ) {
        $Push->($1);
    }

    if ($Parser) {
        my @Attachments = $Parser->GetAttachments();
        ATTACHMENT:
        for my $Attachment (@Attachments) {
            my $Type    = $Attachment->{ContentType} // '';
            my $Content = $Attachment->{Content}     // '';
            next ATTACHMENT if !$Content;
            if ( $Type =~ m{delivery-status}i || $Content =~ m{Final-Recipient:}i ) {
                if ( $Content =~ m{Final-Recipient:\s*(?:rfc822;)?\s*<?([^>\s]+@[^>\s]+)}i ) {
                    $Push->($1);
                }
                if ( $Content =~ m{Original-Recipient:\s*(?:rfc822;)?\s*<?([^>\s]+@[^>\s]+)}i ) {
                    $Push->($1);
                }
            }
        }
    }

    return $Candidates[0] if @Candidates;
    return;
}

sub TicketIDByRecipient {
    my ( $Self, %Param ) = @_;
    my $Email = lc( $Param{Email} // '' );
    return if !$Email;

    my $Data = $Kernel::OM->Get('Kernel::System::BWBCustomerUserEmail')->CustomerUserDataGetByEmail(
        Email => $Email,
    );
    my $Login = $Data ? ( $Data->{UserLogin} || '' ) : '';
    $Login ||= $Email;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => q{
            SELECT t.id
            FROM ticket t
            INNER JOIN ticket_state ts ON ts.id = t.ticket_state_id
            WHERE t.customer_user_id IN (?, ?)
            ORDER BY CASE WHEN ts.type_id IN (3, 6, 7) THEN 1 ELSE 0 END,
                     t.change_time DESC
            LIMIT 1
        },
        Bind => [ \$Login, \$Email ],
    );
    my ($TicketID) = $DB->FetchrowArray();
    return $TicketID;
}

sub FindTicketID {
    my ( $Self, %Param ) = @_;
    my $GetParam = $Param{GetParam} || {};
    return if !$Self->IsBounce( GetParam => $GetParam );

    my $MessageID = $Self->OriginalMessageID( GetParam => $GetParam );
    if ($MessageID) {
        my $TicketID = $Self->TicketIDByMessageID( MessageID => $MessageID );
        return $TicketID if $TicketID;
    }

    my $Recipient = $Self->FailedRecipient(
        GetParam     => $GetParam,
        ParserObject => $Param{ParserObject},
    );
    return if !$Recipient;
    return $Self->TicketIDByRecipient( Email => $Recipient );
}

1;
