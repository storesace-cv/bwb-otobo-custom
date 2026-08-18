package Kernel::Modules::AgentBWBTimeSpent;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {%Param}, $Type;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Layout   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Request  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Service  = $Kernel::OM->Get('Kernel::System::BWBTimeSpent');
    my $TimeZone = $Self->{UserTimeZone} || 'Europe/Lisbon';

    my ( $DefaultFrom, $DefaultTo ) = $Service->DefaultDates( TimeZone => $TimeZone );
    my $FromDate = $Request->GetParam( Param => 'FromDate' ) || $DefaultFrom;
    my $ToDate   = $Request->GetParam( Param => 'ToDate' )   || $DefaultTo;
    my $Period   = $Service->PeriodToUTC(
        FromDate => $FromDate,
        ToDate   => $ToDate,
        TimeZone => $TimeZone,
    );
    if ( !$Period ) {
        $Period = $Service->PeriodToUTC(
            FromDate => $DefaultFrom,
            ToDate   => $DefaultTo,
            TimeZone => $TimeZone,
        );
        $FromDate = $DefaultFrom;
        $ToDate   = $DefaultTo;
    }

    my $Rows = $Service->TeamSessionsInPeriodGet(
        UserID   => $Self->{UserID},
        FromUTC  => $Period->{FromUTC},
        ToUTC    => $Period->{ToUTC},
        TimeZone => $TimeZone,
    );
    my $Totals = $Service->TotalsFromRows($Rows);

    my $Subaction = $Self->{Subaction} || $Request->GetParam( Param => 'Subaction' ) || '';
    if ( $Subaction eq 'PDF' ) {
        my $Summaries = $Service->CustomerSummariesFromRows($Rows);
        my $PDFString = $Kernel::OM->Get('Kernel::Output::PDF::BWBTimeSpent')->GeneratePDF(
            UserID    => $Self->{UserID},
            Rows      => $Rows,
            Totals    => $Totals,
            Summaries => $Summaries,
            FromDate  => $Period->{FromDate},
            ToDate    => $Period->{ToDate},
        );
        if ( !$PDFString ) {
            return $Layout->ErrorScreen(
                Message => 'Não foi possível gerar o PDF.',
            );
        }
        return $Layout->Attachment(
            Filename    => 'Tempo-dispendido-' . $Period->{FromDate} . '-' . $Period->{ToDate} . '.pdf',
            ContentType => 'application/pdf',
            Content     => $PDFString,
            Type        => 'inline',
        );
    }

    for my $Row ( @{$Rows} ) {
        $Layout->Block( Name => 'Row', Data => $Row );
    }
    if ( !@{$Rows} ) {
        $Layout->Block( Name => 'None' );
    }
    for my $Total ( @{ $Totals->{Store} } ) {
        $Layout->Block( Name => 'StoreTotal', Data => $Total );
    }
    for my $Total ( @{ $Totals->{Customer} } ) {
        $Layout->Block( Name => 'CustomerTotal', Data => $Total );
    }

    my $Output = $Layout->Header( Title => 'Tempo dispendido' );
    $Output .= $Layout->NavigationBar();
    $Output .= $Layout->Output(
        TemplateFile => 'AgentBWBTimeSpent',
        Data         => {
            FromDate       => $Period->{FromDate},
            ToDate         => $Period->{ToDate},
            Count          => $Totals->{Count},
            GrandDuration  => $Totals->{Duration},
        },
    );
    $Output .= $Layout->Footer();
    return $Output;
}

1;
