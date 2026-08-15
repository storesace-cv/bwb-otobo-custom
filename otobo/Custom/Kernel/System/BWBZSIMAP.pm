package Kernel::System::BWBZSIMAP;

use strict;
use warnings;
use IO::Socket::SSL ();
use Net::IMAP::Simple ();

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::MailAccount',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub PendingDeleteForTicketIDs {
    my ( $Self, %Param ) = @_;
    return 1 if ref $Param{TicketIDs} ne 'ARRAY' || !@{ $Param{TicketIDs} };

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my @IDs = grep { /^\d+$/ } @{ $Param{TicketIDs} };
    return 1 if !@IDs;
    my $Placeholders = join ',', ('?') x @IDs;
    my @Bind = map { \$_ } @IDs;
    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT adm.a_message_id FROM article a INNER JOIN article_data_mime adm ON adm.article_id=a.id WHERE a.ticket_id IN ($Placeholders) AND a.article_sender_type_id=3 AND adm.a_message_id <> ''",
        Bind => \@Bind,
    );
    my @MessageIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @MessageIDs, $Row[0] if $Row[0];
    }
    return 1 if !@MessageIDs;

    my $IMAP = $Self->_Connect();
    return if !$IMAP;
    my $Folder = 'Helpdesk - Pendentes';
    return if !$IMAP->select($Folder);
    for my $MessageID (@MessageIDs) {
        my $Quoted = $MessageID;
        $Quoted =~ s/([\\"])/\\$1/g;
        my @Messages = $IMAP->search(qq{HEADER Message-ID "$Quoted"});
        $IMAP->delete($_) for @Messages;
    }
    $IMAP->expunge_mailbox($Folder);
    $IMAP->quit();
    return 1;
}

sub ArchiveExpired {
    my ($Self) = @_;
    my $IMAP = $Self->_Connect();
    return if !$IMAP;
    my $Source = 'Helpdesk - Pendentes';
    my $Target = 'Outros - Emails';
    my %Mailbox = map { $_ => 1 } $IMAP->mailboxes();
    $IMAP->create_mailbox($Source) if !$Mailbox{$Source};
    $IMAP->create_mailbox($Target) if !$Mailbox{$Target};
    return if !$IMAP->select($Source);

    my @Cutoff = localtime( time - 30 * 24 * 60 * 60 );
    my @Month = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my $Date = sprintf '%02d-%s-%04d', $Cutoff[3], $Month[ $Cutoff[4] ], $Cutoff[5] + 1900;
    my @Messages = $IMAP->search("BEFORE $Date");
    my $Moved = 0;
    for my $Message (@Messages) {
        next if !$IMAP->copy( $Message, $Target );
        $IMAP->delete($Message);
        $Moved++;
    }
    $IMAP->expunge_mailbox($Source) if $Moved;
    $IMAP->quit();
    return $Moved;
}

sub _Connect {
    my ($Self) = @_;
    my %Account = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountGet( ID => 3 );
    return if !$Account{Login} || !$Account{Password} || !$Account{Host};
    my $IMAP = Net::IMAP::Simple->new(
        $Account{Host},
        timeout => 60,
        use_ssl => 1,
        ssl_options => [
            SSL_verify_mode => $Kernel::OM->Get('Kernel::Config')->Get('PostMasterSSLVerifyMode') // IO::Socket::SSL::SSL_VERIFY_NONE(),
        ],
    );
    return if !$IMAP;
    if ( !defined $IMAP->login( $Account{Login}, $Account{Password} ) ) {
        $IMAP->quit();
        return;
    }
    return $IMAP;
}

1;
