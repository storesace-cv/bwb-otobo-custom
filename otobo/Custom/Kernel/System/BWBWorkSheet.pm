package Kernel::System::BWBWorkSheet;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = qw(Kernel::System::DB);

sub new { my ($Type) = @_; return bless {}, $Type; }

sub DraftGet {
    my ( $Self, %Param ) = @_;
    return {} if !$Param{SessionID};
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return {} if !$DB->Prepare(
        SQL => 'SELECT body,paused_at,paused_seconds,form_id,change_time FROM bwb_work_sheet WHERE session_id=?',
        Bind => [ \$Param{SessionID} ],
    );
    my @Row = $DB->FetchrowArray();
    return @Row ? { Body=>$Row[0]||'', PausedAt=>$Row[1], PausedSeconds=>$Row[2]||0, FormID=>$Row[3]||'', ChangeTime=>$Row[4] } : {};
}

sub DraftSave {
    my ( $Self, %Param ) = @_;
    return if !$Param{SessionID} || !$Param{UserID};
    my $Body = defined $Param{Body} ? $Param{Body} : '';
    my $FormID = $Param{FormID} || '';
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => q{INSERT INTO bwb_work_sheet(session_id,body,form_id,paused_seconds,create_time,create_by,change_time,change_by)
                 VALUES(?,?,?,0,UTC_TIMESTAMP(),?,UTC_TIMESTAMP(),?)
                 ON DUPLICATE KEY UPDATE body=VALUES(body),form_id=VALUES(form_id),change_time=UTC_TIMESTAMP(),change_by=VALUES(change_by)},
        Bind => [ \$Param{SessionID}, \$Body, \$FormID, \$Param{UserID}, \$Param{UserID} ],
    );
}

sub Pause {
    my ( $Self, %Param ) = @_;
    return if !$Param{SessionID} || !$Param{UserID};
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE bwb_work_sheet SET paused_at=COALESCE(paused_at,UTC_TIMESTAMP()),change_time=UTC_TIMESTAMP(),change_by=? WHERE session_id=?',
        Bind => [ \$Param{UserID}, \$Param{SessionID} ],
    );
}

sub Resume {
    my ( $Self, %Param ) = @_;
    return if !$Param{SessionID} || !$Param{UserID};
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE bwb_work_sheet SET paused_seconds=paused_seconds+IF(paused_at IS NULL,0,TIMESTAMPDIFF(SECOND,paused_at,UTC_TIMESTAMP())),paused_at=NULL,change_time=UTC_TIMESTAMP(),change_by=? WHERE session_id=?',
        Bind => [ \$Param{UserID}, \$Param{SessionID} ],
    );
}

1;
