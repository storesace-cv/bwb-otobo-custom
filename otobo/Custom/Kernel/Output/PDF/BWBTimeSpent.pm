package Kernel::Output::PDF::BWBTimeSpent;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::BWBAccess',
    'Kernel::System::BWBTimeSpent',
    'Kernel::System::PDF',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub GeneratePDF {
    my ( $Self, %Param ) = @_;
    return if !$Param{UserID} || !$Param{FromDate} || !$Param{ToDate};

    my $Rows   = $Param{Rows}   || [];
    my $Totals = $Param{Totals} || {};
    my $Summaries = $Param{Summaries};
    if ( !$Summaries ) {
        $Summaries = $Kernel::OM->Get('Kernel::System::BWBTimeSpent')->CustomerSummariesFromRows($Rows);
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $AccessObject = $Kernel::OM->Get('Kernel::System::BWBAccess');

    $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::PDF'] );
    my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

    my $Home = $ConfigObject->Get('Home') || '/opt/otobo';
    my $LogoFile = $AccessObject->IsZSOperationUser( UserID => $Param{UserID} )
        ? "$Home/var/httpd/htdocs/common/img/pdf-header-zs.png"
        : "$Home/var/httpd/htdocs/common/img/pdf-header-bwb.png";
    $LogoFile = '' if !-e $LogoFile;

    my $PageLabel = $LayoutObject->{LanguageObject}
        ? $LayoutObject->{LanguageObject}->Translate('Page')
        : 'Página';
    my $Time = $LayoutObject->{Time} || '';

    my $MaxPages = $ConfigObject->Get('PDF::MaxPages');
    if ( !$MaxPages || $MaxPages < 1 || $MaxPages > 1000 ) {
        $MaxPages = 100;
    }

    my %PageParam = (
        PageOrientation => 'landscape',
        MarginTop       => 30,
        MarginRight     => 40,
        MarginBottom    => 40,
        MarginLeft      => 40,
    );
    $PageParam{LogoFile} = $LogoFile if $LogoFile;

    my $PageCounter = 1;

    $PDFObject->DocumentNew(
        Title  => 'Helpdesk: Tempo dispendido',
        Encode => 'utf8',
    );

    $PDFObject->PageNew(%PageParam);
    $PageCounter++;

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => 'middle',
    );
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => +44,
    );
    $PDFObject->Text(
        Text     => 'Relatório HELPDESK',
        FontSize => 20,
        Align    => 'center',
    );
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -20,
    );
    $PDFObject->Text(
        Text     => 'Tempo dispendido',
        FontSize => 15,
        Align    => 'center',
        Color    => '#555555',
    );
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -16,
    );
    $PDFObject->Text(
        Text     => 'De ' . $Self->_DatePT( $Param{FromDate} ) . ' até ' . $Self->_DatePT( $Param{ToDate} ),
        FontSize => 11,
        Align    => 'center',
        Color    => '#555555',
    );
    if ($Time) {
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -16,
        );
        $PDFObject->Text(
            Text     => $Time,
            FontSize => 9,
            Align    => 'center',
            Color    => '#555555',
        );
    }

    $PDFObject->PageNew(
        %PageParam,
        FooterRight => $PageLabel . ' ' . $PageCounter++,
    );
    my $TOCPage = $PDFObject->{Page};

    $PDFObject->PageNew(
        %PageParam,
        FooterRight => $PageLabel . ' ' . $PageCounter++,
    );

    my $ChapterCounter = 1;
    my @Chapters;

    my $StartChapter = sub {
        my ($Caption) = @_;
        if ( $ChapterCounter > 1 ) {
            $PDFObject->PageNew(
                %PageParam,
                FooterRight => $PageLabel . ' ' . $PageCounter++,
            );
        }
        my $Full = $ChapterCounter++ . ' ' . $Caption;
        push @Chapters, {
            Caption => $Full,
            Page    => $PageCounter - 1,
        };
        $PDFObject->Text(
            Text     => $Full,
            FontSize => 13,
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -13,
        );
        return;
    };

    my $OutputTable = sub {
        my (%TableParam) = @_;
        PAGE:
        while ( $PageCounter <= $MaxPages ) {
            %TableParam = $PDFObject->Table(%TableParam);
            last PAGE if $TableParam{State};
            $PDFObject->PageNew(
                %PageParam,
                FooterRight => $PageLabel . ' ' . $PageCounter++,
            );
        }
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -6,
        );
        return;
    };

    $StartChapter->('Trabalhos');
    $OutputTable->(
        $Self->_WorksTable($Rows),
    );

    $StartChapter->('Totais por loja');
    $OutputTable->(
        $Self->_StoreTotalsTable($Totals),
    );

    $StartChapter->('Totais por cliente');
    $OutputTable->(
        $Self->_CustomerTotalsTable($Totals),
    );

    if ( @{$Summaries} ) {
        my $Full = $ChapterCounter++ . ' Resumo por cliente';
        push @Chapters, {
            Caption => $Full,
            Page    => $PageCounter,
        };
        $Self->_OutputCustomerSummaries(
            PDFObject   => $PDFObject,
            Summaries   => $Summaries,
            PageParam   => \%PageParam,
            PageLabel   => $PageLabel,
            GeneratedAt => $Time,
            MaxPages    => $MaxPages,
            PageCounter => \$PageCounter,
            ChapterTitle => $Full,
        );
    }

    if ($TOCPage) {
        local $PDFObject->{Page} = $TOCPage;
        $PDFObject->PositionSet(
            X => 'left',
            Y => 'top',
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -40,
        );
        $PDFObject->Text(
            Text     => 'Índice',
            FontSize => 16,
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -18,
        );
        for my $Chapter (@Chapters) {
            $PDFObject->Text(
                Text     => $Chapter->{Caption},
                FontSize => 11,
            );
            $PDFObject->PositionSet(
                Move => 'relativ',
                X    => 420,
                Y    => 11,
            );
            $PDFObject->Text(
                Text     => $Chapter->{Page},
                FontSize => 11,
                Align    => 'right',
            );
            $PDFObject->PositionSet(
                X    => 'left',
                Move => 'relativ',
                Y    => -16,
            );
        }
    }

    return $PDFObject->DocumentOutput();
}

sub _OutputCustomerSummaries {
    my ( $Self, %Param ) = @_;

    my $PDFObject   = $Param{PDFObject};
    my $Summaries   = $Param{Summaries} || [];
    my %PageParam   = %{ $Param{PageParam} || {} };
    my $PageLabel   = $Param{PageLabel} || 'Página';
    my $GeneratedAt = $Param{GeneratedAt} || '';
    my $MaxPages    = $Param{MaxPages} || 100;
    my $PageCounter = $Param{PageCounter};

    my $FirstCustomer = 1;
    for my $Summary ( @{$Summaries} ) {
        my $Header = $Summary->{Header} || {};
        my $Rows   = $Summary->{Rows}   || [];
        my $Totals = $Summary->{Totals} || {};
        my $LocalPage = 1;

        my $NewCustomerPage = sub {
            my (%Opt) = @_;
            $PDFObject->PageNew(
                %PageParam,
                FooterLeft  => $GeneratedAt,
                FooterRight => $PageLabel . ' ' . $LocalPage++,
            );
            ${$PageCounter}++;
            if ( $Opt{FullHeader} ) {
                $Self->_WriteCustomerHeader(
                    PDFObject => $PDFObject,
                    Header    => $Header,
                    Title     => $FirstCustomer ? $Param{ChapterTitle} : '',
                );
            }
            else {
                $PDFObject->Text(
                    Text     => $Header->{CustomerName} || '-',
                    FontSize => 11,
                    Font     => 'ProportionalBold',
                );
                $PDFObject->PositionSet(
                    Move => 'relativ',
                    Y    => -10,
                );
            }
            return;
        };

        $NewCustomerPage->( FullHeader => 1 );
        $FirstCustomer = 0;

        my %TableParam = $Self->_CustomerDetailTable($Rows);
        PAGE:
        while ( ${$PageCounter} <= $MaxPages ) {
            %TableParam = $PDFObject->Table(%TableParam);
            last PAGE if $TableParam{State};
            $NewCustomerPage->( FullHeader => 0 );
        }

        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -10,
        );
        $PDFObject->Text(
            Text     => 'Totais do cliente',
            FontSize => 10,
            Font     => 'ProportionalBold',
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -10,
        );
        $PDFObject->Text(
            Text     => 'Total: ' . ( $Totals->{Duration} || '0 min' )
                . '  ('
                . ( $Totals->{Count} || 0 )
                . ' trabalhos)',
            FontSize => 9,
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -8,
        );

        my %StoreTable = $Self->_CustomerStoreTotalsTable($Totals);
        STORE_PAGE:
        while ( ${$PageCounter} <= $MaxPages ) {
            %StoreTable = $PDFObject->Table(%StoreTable);
            last STORE_PAGE if $StoreTable{State};
            $NewCustomerPage->( FullHeader => 0 );
        }
    }

    return 1;
}

sub _WriteCustomerHeader {
    my ( $Self, %Param ) = @_;
    my $PDFObject = $Param{PDFObject};
    my $Header    = $Param{Header} || {};

    if ( $Param{Title} ) {
        $PDFObject->Text(
            Text     => $Param{Title},
            FontSize => 13,
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -12,
        );
    }

    $PDFObject->Text(
        Text     => $Header->{CustomerName} || '-',
        FontSize => 12,
        Font     => 'ProportionalBold',
    );
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -10,
    );

    if ( $Header->{CustomerID} ) {
        $PDFObject->Text(
            Text     => 'Cliente ID: ' . $Header->{CustomerID},
            FontSize => 9,
            Color    => '#555555',
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -9,
        );
    }

    my @AddressParts = grep {$_} (
        $Header->{Street},
        join( ' ', grep {$_} ( $Header->{ZIP}, $Header->{City} ) ),
        $Header->{Country},
    );
    if (@AddressParts) {
        $PDFObject->Text(
            Text     => join( ' · ', @AddressParts ),
            FontSize => 9,
            Color    => '#555555',
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -9,
        );
    }
    if ( $Header->{Phone} ) {
        $PDFObject->Text(
            Text     => 'Telefone: ' . $Header->{Phone},
            FontSize => 9,
            Color    => '#555555',
        );
        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -9,
        );
    }

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -4,
    );
    return 1;
}

sub _WorksTable {
    my ( $Self, $Rows ) = @_;

    my @Heads = (
        'Cliente', 'Loja', 'Ticket#', 'Título', 'Técnico', 'Tipo',
        'Estado',  'Início', 'Fim', 'Duração', 'Resultado',
    );
    my $CellData = [];
    my $Col      = 0;
    for my $Head (@Heads) {
        $CellData->[0]->[$Col] = {
            Content => $Head,
            Font    => 'ProportionalBold',
        };
        $Col++;
    }

    my $RowIdx = 1;
    for my $Row ( @{ $Rows || [] } ) {
        my @Values = (
            $Row->{Customer},
            $Row->{Store},
            $Row->{TicketNumber},
            $Self->_Clip( $Row->{Title}, 48 ),
            $Row->{Technician},
            $Row->{WorkType},
            $Row->{Status},
            $Row->{Start},
            $Row->{End},
            $Row->{Duration},
            $Self->_Clip( $Row->{Result}, 32 ),
        );
        my $ColIdx = 0;
        for my $Value (@Values) {
            $CellData->[$RowIdx]->[$ColIdx]{Content} = $Self->_Cell($Value);
            $ColIdx++;
        }
        $RowIdx++;
    }
    if ( $RowIdx == 1 ) {
        $CellData->[1]->[0]{Content} = 'Não há folhas de trabalho da equipa neste intervalo.';
    }

    return (
        CellData            => $CellData,
        Type                => 'Cut',
        FontSize            => 6,
        Border              => 0,
        BackgroundColorEven => '#DDDDDD',
        Padding             => 3,
    );
}

sub _CustomerDetailTable {
    my ( $Self, $Rows ) = @_;

    my @Heads = (
        'Loja', 'Data', 'Ticket#', 'Utilizador cliente', 'Título', 'Técnico',
        'Tipo', 'Estado', 'Início', 'Fim', 'Duração', 'Resultado',
    );
    my $CellData = [];
    my $Col      = 0;
    for my $Head (@Heads) {
        $CellData->[0]->[$Col] = {
            Content => $Head,
            Font    => 'ProportionalBold',
        };
        $Col++;
    }

    my $RowIdx = 1;
    for my $Row ( @{ $Rows || [] } ) {
        my @Values = (
            $Row->{Store},
            $Row->{StartDate},
            $Row->{TicketNumber},
            $Self->_Clip( $Row->{CustomerUserName}, 28 ),
            $Self->_Clip( $Row->{Title},            40 ),
            $Row->{Technician},
            $Row->{WorkType},
            $Row->{Status},
            $Row->{Start},
            $Row->{End},
            $Row->{Duration},
            $Self->_Clip( $Row->{Result}, 28 ),
        );
        my $ColIdx = 0;
        for my $Value (@Values) {
            $CellData->[$RowIdx]->[$ColIdx]{Content} = $Self->_Cell($Value);
            $ColIdx++;
        }
        $RowIdx++;
    }
    if ( $RowIdx == 1 ) {
        $CellData->[1]->[0]{Content} = 'Sem trabalhos neste cliente.';
    }

    return (
        CellData            => $CellData,
        Type                => 'Cut',
        FontSize            => 6,
        Border              => 0,
        BackgroundColorEven => '#DDDDDD',
        Padding             => 3,
    );
}

sub _StoreTotalsTable {
    my ( $Self, $Totals ) = @_;
    my $CellData = [];
    $CellData->[0] = [
        { Content => 'Cliente', Font => 'ProportionalBold' },
        { Content => 'Loja',    Font => 'ProportionalBold' },
        { Content => 'Tempo',   Font => 'ProportionalBold' },
    ];
    my $RowIdx = 1;
    for my $Row ( @{ $Totals->{Store} || [] } ) {
        $CellData->[$RowIdx] = [
            { Content => $Self->_Cell( $Row->{Customer} ) },
            { Content => $Self->_Cell( $Row->{Store} ) },
            { Content => $Self->_Cell( $Row->{Duration} ) },
        ];
        $RowIdx++;
    }
    $CellData->[$RowIdx] = [
        { Content => 'Total', Font => 'ProportionalBold' },
        { Content => '' },
        { Content => $Self->_Cell( $Totals->{Duration} ), Font => 'ProportionalBold' },
    ];
    return (
        CellData            => $CellData,
        Type                => 'Cut',
        FontSize            => 8,
        Border              => 0,
        BackgroundColorEven => '#DDDDDD',
        Padding             => 4,
    );
}

sub _CustomerStoreTotalsTable {
    my ( $Self, $Totals ) = @_;
    my $CellData = [];
    $CellData->[0] = [
        { Content => 'Loja',  Font => 'ProportionalBold' },
        { Content => 'Tempo', Font => 'ProportionalBold' },
    ];
    my $RowIdx = 1;
    for my $Row ( @{ $Totals->{Store} || [] } ) {
        $CellData->[$RowIdx] = [
            { Content => $Self->_Cell( $Row->{Store} ) },
            { Content => $Self->_Cell( $Row->{Duration} ) },
        ];
        $RowIdx++;
    }
    if ( $RowIdx == 1 ) {
        $CellData->[1]->[0]{Content} = '-';
        $CellData->[1]->[1]{Content} = '0 min';
    }
    return (
        CellData            => $CellData,
        Type                => 'Cut',
        FontSize            => 8,
        Border              => 0,
        BackgroundColorEven => '#DDDDDD',
        Padding             => 4,
    );
}

sub _CustomerTotalsTable {
    my ( $Self, $Totals ) = @_;
    my $CellData = [];
    $CellData->[0] = [
        { Content => 'Cliente', Font => 'ProportionalBold' },
        { Content => 'Tempo',   Font => 'ProportionalBold' },
    ];
    my $RowIdx = 1;
    for my $Row ( @{ $Totals->{Customer} || [] } ) {
        $CellData->[$RowIdx] = [
            { Content => $Self->_Cell( $Row->{Customer} ) },
            { Content => $Self->_Cell( $Row->{Duration} ) },
        ];
        $RowIdx++;
    }
    $CellData->[$RowIdx] = [
        { Content => 'Total', Font => 'ProportionalBold' },
        { Content => $Self->_Cell( $Totals->{Duration} ), Font => 'ProportionalBold' },
    ];
    return (
        CellData            => $CellData,
        Type                => 'Cut',
        FontSize            => 8,
        Border              => 0,
        BackgroundColorEven => '#DDDDDD',
        Padding             => 4,
    );
}

sub _Cell {
    my ( $Self, $Value ) = @_;
    return '-' if !defined $Value || $Value eq '';
    return $Value;
}

sub _Clip {
    my ( $Self, $Value, $Max ) = @_;
    $Value = $Self->_Cell($Value);
    return $Value if length($Value) <= $Max;
    return substr( $Value, 0, $Max - 1 ) . '…';
}

sub _DatePT {
    my ( $Self, $ISO ) = @_;
    return $ISO if !$ISO || $ISO !~ /^(\d{4})-(\d{2})-(\d{2})$/;
    return "$3/$2/$1";
}

1;
