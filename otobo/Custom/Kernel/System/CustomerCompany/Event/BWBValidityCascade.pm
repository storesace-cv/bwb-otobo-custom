package Kernel::System::CustomerCompany::Event::BWBValidityCascade;
use strict;use warnings;
our @ObjectDependencies=qw(Kernel::System::DB);
sub new{my($T)=@_;bless{},$T}
sub Run{my($S,%P)=@_;return 1 if !$P{Data}{NewData};my $CID=$P{Data}{CustomerID}||return 1;my $Valid=$P{Data}{NewData}{ValidID};return 1 if !defined $Valid;my $Target=$Valid==1?1:3;my $DB=$Kernel::OM->Get('Kernel::System::DB');$DB->Do(SQL=>'UPDATE customer_user SET valid_id=?,change_time=current_timestamp,change_by=? WHERE customer_id=?',Bind=>[\$Target,\$P{UserID},\$CID]);return 1}
1;
