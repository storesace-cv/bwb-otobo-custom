package Kernel::Modules::AgentBWBWorkSession;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new { my ( $Type, %Param ) = @_; return bless { %Param }, $Type; }

sub Run {
    my ($Self) = @_;
    my $Layout  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Work    = $Kernel::OM->Get('Kernel::System::BWBWorkSession');
    my $Sheet   = $Kernel::OM->Get('Kernel::System::BWBWorkSheet');
    my $Types   = $Kernel::OM->Get('Kernel::System::BWBOperationType');
    my $Results = $Kernel::OM->Get('Kernel::System::BWBResultType');
    my $Ticket  = $Kernel::OM->Get('Kernel::System::Ticket');

    my $TicketID = $Self->{TicketID} || $Request->GetParam( Param => 'TicketID' ) || 0;
    return $Layout->ErrorScreen( Message => 'Ticket inválido.' ) if !$TicketID;
    return $Layout->NoPermission( WithHeader => 'yes' ) if !$Ticket->TicketPermission( Type=>'rw', TicketID=>$TicketID, UserID=>$Self->{UserID}, LogNo=>1 );

    my %TicketData = $Ticket->TicketGet( TicketID=>$TicketID, DynamicFields=>0, Silent=>1 );
    my %CustomerUserData;
    if ( $TicketData{CustomerUserID} ) {
        %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $TicketData{CustomerUserID},
        );
    }
    my %CustomerCompanyData;
    if ( $TicketData{CustomerID} ) {
        %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $TicketData{CustomerID},
        );
    }
    my %TechnicianData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Self->{UserID},
    );
    my $CustomerUserName = $CustomerUserData{UserFullname}
        || join( ' ', grep { defined $_ && length $_ } @CustomerUserData{qw(UserFirstname UserLastname)} )
        || $TicketData{CustomerUserID}
        || 'Utilizador do cliente';
    my $TechnicianName = $TechnicianData{UserFullname}
        || join( ' ', grep { defined $_ && length $_ } @TechnicianData{qw(UserFirstname UserLastname)} )
        || $TechnicianData{UserLogin}
        || 'Técnico';
    my $Active = $Work->ActiveGet( UserID=>$Self->{UserID} );
    if ( $Active && $Active->{TicketID} != $TicketID ) {
        return $Layout->ErrorScreen( Message=>'Já tem um trabalho ativo noutro ticket.' );
    }
    my $FormID = $Request->GetParam( Param=>'FormID' ) || ( $Active ? 'BWBWork'.$Active->{SessionID} : 'BWBWorkNew'.$Self->{UserID}.$TicketID );
    my %Data = (
        TicketID=>$TicketID, TicketNumber=>$TicketData{TicketNumber}, TicketTitle=>$TicketData{Title},
        CustomerID=>$TicketData{CustomerID}||'',
        CustomerName=>$CustomerCompanyData{CustomerCompanyName}||$TicketData{CustomerName}||$TicketData{CustomerID}||'Cliente',
        CustomerUserName=>$CustomerUserName, TechnicianName=>$TechnicianName, Active=>$Active?1:0,
        WorkTypes=>$Types->AvailableList(UserID=>$Self->{UserID}), Results=>$Results->AvailableList(UserID=>$Self->{UserID}),
        FormID=>$FormID,
    );

    if ( $Self->{Subaction} eq 'Start' ) {
        $Layout->ChallengeTokenCheck();
        my $Requested=$Request->GetParam(Param=>'WorkType')||'';
        my $Allowed=$Types->NameAllowed(UserID=>$Self->{UserID},Name=>$Requested);
        if (!$Allowed) { $Data{Error}='Selecione um tipo de intervenção válido.'; }
        elsif (!$Work->Start(UserID=>$Self->{UserID},TicketID=>$TicketID,WorkType=>$Allowed,NoArticle=>1)) { $Data{Error}='Não foi possível iniciar o trabalho.'; }
        else {
            $Active=$Work->ActiveGet(UserID=>$Self->{UserID});
            $FormID='BWBWork'.$Active->{SessionID};
            $Sheet->DraftSave(SessionID=>$Active->{SessionID},UserID=>$Self->{UserID},Body=>'',FormID=>$FormID);
            return $Layout->Redirect( OP=>'Action=AgentBWBWorkSession;TicketID='.$TicketID );
        }
    }

    $Active=$Work->ActiveGet(UserID=>$Self->{UserID});
    my $Draft=$Active ? $Sheet->DraftGet(SessionID=>$Active->{SessionID}) : {};
    $Data{Active}=$Active?1:0; $Data{WorkType}=$Active->{WorkType}; $Data{StartTime}=$Active->{StartTime};
    $Data{Body}=$Draft->{Body}||''; $Data{Paused}=$Draft->{PausedAt}?1:0; $Data{FormID}=$Draft->{FormID}||$FormID;

    if ( $Active && $Self->{Subaction} eq 'Cancel' ) {
        $Layout->ChallengeTokenCheck();
        my $DB = $Kernel::OM->Get('Kernel::System::DB');
        my $DraftRemoved = $DB->Do(
            SQL  => 'DELETE FROM bwb_work_sheet WHERE session_id=?',
            Bind => [ \$Active->{SessionID} ],
        );
        my $SessionRemoved = $DraftRemoved && $DB->Do(
            SQL  => 'DELETE FROM bwb_work_session WHERE id=? AND user_id=? AND end_time IS NULL',
            Bind => [ \$Active->{SessionID}, \$Self->{UserID} ],
        );
        if ( $SessionRemoved ) {
            $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDRemove( FormID => $Data{FormID} );
            my $FieldMode = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
            my $Pref = $FieldMode->PreferenceGet( UserID => $Self->{UserID} );
            if ( $FieldMode->IsCollaborator( UserID => $Self->{UserID} ) && !( defined $Pref && $Pref eq '0' ) ) {
                return $Layout->Redirect( OP => 'Action=AgentBWBFieldHome' );
            }
            return $Layout->Redirect( OP=>'Action=AgentTicketZoom;TicketID='.$TicketID );
        }
        $Data{Error} = 'Não foi possível cancelar a folha de trabalho. O ticket não foi alterado.';
    }

    if ( $Active && $Self->{Subaction} =~ /^(SaveDraft|Pause|Resume|Finish)$/ ) {
        $Layout->ChallengeTokenCheck();
        my $Body=$Request->GetParam(Param=>'Body')||'';
        $Sheet->DraftSave(SessionID=>$Active->{SessionID},UserID=>$Self->{UserID},Body=>$Body,FormID=>$Data{FormID});
        if ($Self->{Subaction} eq 'SaveDraft') {
            return $Layout->Attachment(ContentType=>'application/json',Content=>'{"Success":true}',Type=>'inline',NoCache=>1);
        }
        if ($Self->{Subaction} eq 'Pause') { $Sheet->Pause(SessionID=>$Active->{SessionID},UserID=>$Self->{UserID}); return $Layout->Redirect(OP=>'Action=AgentBWBWorkSession;TicketID='.$TicketID); }
        if ($Self->{Subaction} eq 'Resume') { $Sheet->Resume(SessionID=>$Active->{SessionID},UserID=>$Self->{UserID}); return $Layout->Redirect(OP=>'Action=AgentBWBWorkSession;TicketID='.$TicketID); }
        my $Visibility=$Request->GetParam(Param=>'Visibility')||'';
        my $SendEmail=$Request->GetParam(Param=>'SendEmail')||'no';
        my $Requested=$Request->GetParam(Param=>'Result')||'';
        my $Allowed=$Results->NameAllowed(UserID=>$Self->{UserID},Name=>$Requested);
        if (!$Allowed) { $Data{Error}='Selecione um resultado válido.'; }
        elsif ($Visibility ne 'yes' && $Visibility ne 'no') { $Data{Error}='Indique explicitamente se o registo fica visível para o cliente.'; }
        elsif ($SendEmail ne 'yes' && $SendEmail ne 'no') { $Data{Error}='Indique explicitamente se pretende enviar a folha de trabalho por e-mail.'; }
        elsif ($SendEmail eq 'yes' && $Visibility ne 'yes') { $Data{Error}='Para enviar a folha por e-mail, torne também o registo visível no portal do cliente.'; }
        else {
            my @Attachments=$Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDGetAllFilesData(FormID=>$Data{FormID});
            my $Minutes=$Work->Finish(UserID=>$Self->{UserID},TicketID=>$TicketID,Result=>$Allowed,Observation=>$Body,
                IsVisibleForCustomer=>($Visibility eq 'yes'?1:0),SendEmailToCustomer=>($SendEmail eq 'yes'?1:0),Attachment=>\@Attachments,
                Decision=>($Request->GetParam(Param=>'Decision')||''),State=>($Request->GetParam(Param=>'State')||''),
                NewOwnerID=>($Request->GetParam(Param=>'NewOwnerID')||0),PendingDate=>($Request->GetParam(Param=>'PendingDate')||''));
            if ($Minutes) {
                $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDRemove(FormID=>$Data{FormID});
                my $FieldMode = $Kernel::OM->Get('Kernel::System::BWBFieldMode');
                my $Pref = $FieldMode->PreferenceGet( UserID => $Self->{UserID} );
                if ( $FieldMode->IsCollaborator( UserID => $Self->{UserID} ) && !( defined $Pref && $Pref eq '0' ) ) {
                    return $Layout->Redirect( OP => 'Action=AgentBWBFieldHome' );
                }
                return $Layout->Redirect(OP=>'Action=AgentTicketZoom;TicketID='.$TicketID);
            }
            $Data{Error}=$Work->LastError()||'Não foi possível terminar o trabalho.';
        }
    }

    my @Owners=$Ticket->TicketOwnerList(TicketID=>$TicketID); $Data{Owners}=\@Owners;
    my @Meta=$Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDGetAllFilesMeta(FormID=>$Data{FormID});
    for my $Item (@Meta) { $Item->{Filesize} = $Layout->HumanReadableDataSize( Size => $Item->{Filesize} ); }
    $Data{AttachmentList}=\@Meta;
    my $Output=$Layout->Header( Title => ($Data{CustomerName}.' — Folha de trabalho') );
    $Output.=$Layout->Output(TemplateFile=>'AgentBWBWorkSession',Data=>\%Data);
    $Output.=$Layout->Footer();
    return $Output;
}
1;
