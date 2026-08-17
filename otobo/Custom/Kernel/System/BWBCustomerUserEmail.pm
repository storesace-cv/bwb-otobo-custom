package Kernel::System::BWBCustomerUserEmail;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CheckItem',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub CustomerUserDataGetByEmail {
    my ( $Self, %Param ) = @_;
    my $Email = $Self->_NormalizeEmail( $Param{Email} );
    return if !$Email;

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %Candidates = $CustomerUserObject->CustomerSearch(
        PostMasterSearch => $Email,
        Valid            => 1,
    );
    for my $Login ( sort keys %Candidates ) {
        my %Data = $CustomerUserObject->CustomerUserDataGet( User => $Login );
        next if !%Data || lc( $Data{UserEmail} // '' ) ne $Email;
        return {
            %Data,
            UserLogin         => $Login,
            MatchedEmail      => $Email,
            MatchedEmailType  => 'default',
        };
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL   => 'SELECT customer_user_login FROM bwb_customer_user_email WHERE email = ?',
        Bind  => [ \$Email ],
        Limit => 1,
    );
    my ($Login) = $DBObject->FetchrowArray();
    return if !$Login;

    my %Data = $CustomerUserObject->CustomerUserDataGet( User => $Login );
    return if !%Data || ( $Data{ValidID} // 0 ) != 1;
    return {
        %Data,
        UserLogin         => $Login,
        MatchedEmail      => $Email,
        MatchedEmailType  => 'additional',
    };
}

sub EmailsGet {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{CustomerUserLogin};
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DBObject->Prepare(
        SQL  => 'SELECT email FROM bwb_customer_user_email WHERE customer_user_login = ? ORDER BY id ASC',
        Bind => [ \$Param{CustomerUserLogin} ],
    );
    my @Emails;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Emails, $Row[0] if $Row[0];
    }
    return \@Emails;
}

sub EmailsSet {
    my ( $Self, %Param ) = @_;
    $Self->{LastError} = '';
    my $Login = $Param{CustomerUserLogin} || '';
    return $Self->_Error('Utilizador de cliente inválido.') if !$Login;

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %UserData = $CustomerUserObject->CustomerUserDataGet( User => $Login );
    return $Self->_Error('Utilizador de cliente não encontrado.') if !%UserData;

    my $Emails = $Self->EmailsValidate(
        CustomerUserLogin => $Login,
        PrimaryEmail      => $UserData{UserEmail},
        Emails            => $Param{Emails},
    );
    return if !$Emails;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return $Self->_Error('Não foi possível atualizar os e-mails adicionais.') if !$DBObject->Do(
        SQL  => 'DELETE FROM bwb_customer_user_email WHERE customer_user_login = ?',
        Bind => [ \$Login ],
    );
    for my $Email ( @{$Emails} ) {
        return $Self->_Error('Não foi possível guardar um dos e-mails adicionais.') if !$DBObject->Do(
            SQL  => 'INSERT INTO bwb_customer_user_email (customer_user_login, email, create_time, create_by, change_time, change_by) VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [ \$Login, \$Email, \( $Param{UserID} || 1 ), \( $Param{UserID} || 1 ) ],
        );
    }
    return 1;
}

sub EmailsValidate {
    my ( $Self, %Param ) = @_;
    $Self->{LastError} = '';
    my $Login = $Param{CustomerUserLogin} || '';
    my $PrimaryEmail = $Self->_NormalizeEmail( $Param{PrimaryEmail} );
    my %Seen;
    my @Emails = grep { $_ && !$Seen{$_}++ } map { $Self->_NormalizeEmail($_) } @{ $Param{Emails} || [] };
    @Emails = grep { $_ ne $PrimaryEmail } @Emails;
    return $Self->_Error('Só são permitidos dois e-mails adicionais.') if @Emails > 2;

    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');
    for my $Email (@Emails) {
        return $Self->_Error("O endereço $Email não é válido.") if !$CheckItemObject->CheckEmail( Address => $Email );
        my $Existing = $Self->CustomerUserDataGetByEmail( Email => $Email );
        if ( $Existing && ( !$Login || $Existing->{UserLogin} ne $Login ) ) {
            return $Self->_Error("O endereço $Email já pertence a outro utilizador de cliente.");
        }
    }
    return \@Emails;
}

sub EmailAdd {
    my ( $Self, %Param ) = @_;
    my @Emails = @{ $Self->EmailsGet( CustomerUserLogin => $Param{CustomerUserLogin} ) };
    push @Emails, $Param{Email};
    return $Self->EmailsSet( %Param, Emails => \@Emails );
}

sub LastError { return $_[0]->{LastError} || ''; }

sub _NormalizeEmail {
    my ( $Self, $Email ) = @_;
    $Email //= '';
    $Email =~ s/^\s+|\s+$//g;
    return lc $Email;
}

sub _Error {
    my ( $Self, $Message ) = @_;
    $Self->{LastError} = $Message;
    return;
}

1;
