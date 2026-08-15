package Kernel::Output::HTML::TicketMenu::BWBWorkSession;
use parent 'Kernel::Output::HTML::Base';use strict;use warnings;
our @ObjectDependencies=qw(Kernel::System::BWBWorkSession Kernel::System::Ticket);
sub Run{my($S,%P)=@_;return if!$P{Ticket};return if!$Kernel::OM->Get('Kernel::System::Ticket')->TicketPermission(Type=>'rw',TicketID=>$P{Ticket}{TicketID},UserID=>$S->{UserID},LogNo=>1);my$A=$Kernel::OM->Get('Kernel::System::BWBWorkSession')->ActiveGet(UserID=>$S->{UserID});return if$A&&$A->{TicketID}!=$P{Ticket}{TicketID};return{%{$P{Config}},%{$P{Ticket}},Name=>$A?'Terminar trabalho':'Iniciar trabalho',Description=>$A?'Terminar e contabilizar o trabalho':'Iniciar a contabilização do trabalho',Link=>'Action=AgentBWBWorkSession;TicketID='.$P{Ticket}{TicketID},PopupType=>'TicketAction'} }
1;
