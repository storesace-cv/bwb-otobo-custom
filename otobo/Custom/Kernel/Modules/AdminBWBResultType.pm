package Kernel::Modules::AdminBWBResultType;
use strict;use warnings;use utf8;
sub new{my($T,%P)=@_;return bless{%P},$T}
sub Run{my($S)=@_;my$L=$Kernel::OM->Get('Kernel::Output::HTML::Layout');my$P=$Kernel::OM->Get('Kernel::System::Web::Request');my$O=$Kernel::OM->Get('Kernel::System::BWBResultType');my$A=$P->GetParam(Param=>'Subaction')||'';my%D;
if($A eq'Add'){$L->ChallengeTokenCheck();$D{Message}=$O->Add(UserID=>$S->{UserID},Name=>($P->GetParam(Param=>'Name')||''))?'Resultado criado.':'Não foi possível criar o resultado.'}
elsif($A eq'UpdateOwn'){$L->ChallengeTokenCheck();$D{Message}=$O->OwnUpdate(UserID=>$S->{UserID},ID=>scalar$P->GetParam(Param=>'ID'),Name=>scalar($P->GetParam(Param=>'Name')||''),ValidID=>scalar($P->GetParam(Param=>'ValidID')||2))?'Resultado atualizado.':'Não foi possível atualizar o resultado.'}
elsif($A eq'ToggleGlobal'){$L->ChallengeTokenCheck();$D{Message}=$O->GlobalHiddenSet(UserID=>$S->{UserID},ID=>scalar$P->GetParam(Param=>'ID'),Hidden=>scalar($P->GetParam(Param=>'Hidden')||0))?'Disponibilidade atualizada para a sua equipa.':'Não foi possível atualizar a disponibilidade.'}
$D{Items}=$O->List(UserID=>$S->{UserID});my$Out=$L->Header();$Out.=$L->NavigationBar();$Out.=$L->Output(TemplateFile=>'AdminBWBResultType',Data=>\%D);$Out.=$L->Footer();return$Out}
1;
