package Kernel::Config::Files::ZZZBWBDashboardClosed;
use strict;
use warnings;
use utf8;
sub Load {
    my ($File,$Self)=@_;
    $Self->{'DashboardBackend'}->{'0120-TicketNew'}->{Limit}='25';
    $Self->{'DashboardBackend'}->{'0120-TicketNew'}->{DefaultColumns}->{CustomerCompanyName}='2';
    $Self->{'DashboardBackend'}->{'0120-TicketNew'}->{DefaultColumns}->{DynamicField_BWBStore}='2';
    $Self->{'DashboardBackend'}->{'0129-TicketWaitingCustomer'} = {
        Attributes => 'States=Pendente a aguardar cliente;SortBy=Age;OrderBy=Up;',
        Block         => 'ContentLarge',
        CacheTTLLocal => '0.5',
        Default       => '1',
        DefaultColumns => {
            Age                  => '2',
            CustomerCompanyName  => '2',
            CustomerName         => '1',
            DynamicField_BWBStore => '2',
            Owner                => '1',
            State                => '2',
            TicketNumber         => '2',
            Title                => '2',
            Changed              => '1',
        },
        Description => 'Tickets à espera de resposta do cliente (estado Pendente a aguardar cliente).',
        Filter      => 'All',
        Group       => '',
        Limit       => '25',
        Mandatory   => '0',
        Module      => 'Kernel::Output::HTML::Dashboard::TicketGeneric',
        Permission  => 'rw',
        Time        => 'Age',
        Title       => 'A aguardar resposta do cliente',
    };
    $Self->{'DashboardBackend'}->{'0130-TicketOpen'}->{Limit}='25';
    $Self->{'DashboardBackend'}->{'0130-TicketOpen'}->{DefaultColumns}->{CustomerCompanyName}='2';
    $Self->{'DashboardBackend'}->{'0130-TicketOpen'}->{DefaultColumns}->{DynamicField_BWBStore}='2';
    delete $Self->{'DashboardBackend'}->{'0150-TicketClosedRecent'};
    $Self->{'DashboardBackend'}->{'0271-TicketClosedRecent'} = {
        Attributes=>'StateType=closed;TicketCloseTimeNewerMinutes=11520;SortBy=Changed;OrderBy=Down;',
        Block=>'ContentLarge', CacheTTLLocal=>'0.5', Default=>'1',
        DefaultColumns=>{ CustomerCompanyName=>'2', DynamicField_BWBStore=>'2', CustomerName=>'1', State=>'1', TicketNumber=>'2', Title=>'2', Changed=>'2' },
        Description=>'Os últimos 15 tickets fechados nos últimos oito dias.',
        ExcludeAdministrativeCloseHistory=>'1', MaximumTickets=>'15',
        Filter=>'All', Group=>'', Limit=>'15', Mandatory=>'0',
        Module=>'Kernel::Output::HTML::Dashboard::TicketGeneric',
        Permission=>'rw', Time=>'Changed', Title=>'Tickets Fechados',
    };
    return 1;
}
1;
