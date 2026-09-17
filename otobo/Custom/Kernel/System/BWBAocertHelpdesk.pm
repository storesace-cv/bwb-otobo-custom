# --
# Ficha Heldesk AOcert por operação. Sem valores por defeito: o que não
# estiver gravado não é inventado.
# --
package Kernel::System::BWBAocertHelpdesk;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::BWBAccess',
    'Kernel::System::DB',
    'Kernel::System::JSON',
    'Kernel::System::Log',
);

use constant MAX_PHONES     => 30;
use constant MAX_PHONE_LEN  => 80;
use constant MAX_EMAIL_LEN  => 190;
use constant MAX_PORTAL_LEN => 240;

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub OperationFromCustomerID {
    my ( $Self, $CustomerID ) = @_;
    return if !defined $CustomerID || $CustomerID eq '';
    return 'zs' if $CustomerID =~ /\A ZSA/ix;
    return 'bwb';
}

sub VisibleOperations {
    my ( $Self, %Param ) = @_;
    my $UserID = $Param{UserID} || return ();
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    if ( $Access->IsGlobalAdministrator( UserID => $UserID ) ) {
        return ( 'bwb', 'zs' );
    }
    return ('zs') if $Access->IsZSOperationUser( UserID => $UserID );
    return ('bwb');
}

sub CanEdit {
    my ( $Self, %Param ) = @_;
    my $Op = $Self->_NormOp( $Param{Operation} ) || return 0;
    my %Ok = map { $_ => 1 } $Self->VisibleOperations( UserID => $Param{UserID} );
    return $Ok{$Op} ? 1 : 0;
}

sub Get {
    my ( $Self, %Param ) = @_;
    my $Op = $Self->_NormOp( $Param{Operation} ) || return;
    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => q{
            SELECT operation, email, portal, contacts_json, change_time, change_by
            FROM bwb_aocert_helpdesk WHERE operation = ?
        },
        Bind  => [ \$Op ],
        Limit => 1,
    );
    my @Row = $DB->FetchrowArray();
    return if !@Row;
    return $Self->_Row(@Row);
}

sub ListForUser {
    my ( $Self, %Param ) = @_;
    my @Out;
    for my $Op ( $Self->VisibleOperations( UserID => $Param{UserID} ) ) {
        my $Row = $Self->Get( Operation => $Op );
        if ($Row) {
            push @Out, $Row;
            next;
        }
        push @Out, {
            operation => $Op,
            email     => '',
            portal    => '',
            phones    => [],
            complete  => 0,
            label     => $Op eq 'zs' ? 'ZS Angola' : 'BWB',
        };
    }
    return \@Out;
}

sub Set {
    my ( $Self, %Param ) = @_;
    my $UserID = $Param{UserID} || return;
    my $Op     = $Self->_NormOp( $Param{Operation} ) || return;
    return if !$Self->CanEdit( UserID => $UserID, Operation => $Op );

    my $Email  = $Self->_ClipEmail( $Param{Email} );
    my $Portal = $Self->_ClipPortal( $Param{Portal} );
    my @Phones = $Self->_NormPhones( $Param{Phones} );
    return if !$Email || !$Portal || !@Phones;

    my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode( Data => \@Phones );
    return if !$JSON;

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return $DB->Do(
        SQL => q{
            INSERT INTO bwb_aocert_helpdesk
                (operation, email, portal, contacts_json, create_time, create_by, change_time, change_by)
            VALUES (?, ?, ?, ?, UTC_TIMESTAMP(), ?, UTC_TIMESTAMP(), ?)
            ON DUPLICATE KEY UPDATE
                email = VALUES(email),
                portal = VALUES(portal),
                contacts_json = VALUES(contacts_json),
                change_time = UTC_TIMESTAMP(),
                change_by = VALUES(change_by)
        },
        Bind => [ \$Op, \$Email, \$Portal, \$JSON, \$UserID, \$UserID ],
    );
}

sub PublicPayload {
    my ( $Self, %Param ) = @_;
    my $Row = $Self->Get( Operation => $Param{Operation} ) || return;
    return if !$Row->{complete};
    return {
        ok         => 1,
        operation  => $Row->{operation},
        email      => $Row->{email},
        portal     => $Row->{portal},
        phones     => $Row->{phones},
    };
}

sub _Row {
    my ( $Self, @Row ) = @_;
    my $Decoded = $Kernel::OM->Get('Kernel::System::JSON')->Decode( Data => $Row[3] || '[]' );
    my @Phones  = $Self->_NormPhones($Decoded);
    my $Email   = $Self->_ClipEmail( $Row[1] );
    my $Portal  = $Self->_ClipPortal( $Row[2] );
    return {
        operation   => $Row[0],
        email       => $Email || '',
        portal      => $Portal || '',
        phones      => \@Phones,
        change_time => $Row[4],
        change_by   => $Row[5],
        complete    => ( $Email && $Portal && @Phones ) ? 1 : 0,
        label       => $Row[0] eq 'zs' ? 'ZS Angola' : 'BWB',
    };
}

sub _NormOp {
    my ( $Self, $Op ) = @_;
    return if !defined $Op;
    $Op = lc $Op;
    return $Op if $Op eq 'bwb' || $Op eq 'zs';
    return;
}

sub _ClipEmail {
    my ( $Self, $Value ) = @_;
    return if !defined $Value;
    $Value =~ s/^\s+|\s+$//g;
    return if $Value eq '' || length($Value) > MAX_EMAIL_LEN();
    return if $Value !~ /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/;
    return $Value;
}

sub _ClipPortal {
    my ( $Self, $Value ) = @_;
    return if !defined $Value;
    $Value =~ s/^\s+|\s+$//g;
    return if $Value eq '' || length($Value) > MAX_PORTAL_LEN();
    return if $Value !~ m{\Ahttps://}i;
    return $Value;
}

sub _NormPhones {
    my ( $Self, $List ) = @_;
    my @Raw;
    if ( ref $List eq 'ARRAY' ) {
        @Raw = @{$List};
    }
    elsif ( defined $List && $List ne '' ) {
        @Raw = ($List);
    }
    my @Out;
    my %Seen;
    for my $Item (@Raw) {
        next if !defined $Item;
        $Item =~ s/^\s+|\s+$//g;
        next if $Item eq '';
        $Item = substr( $Item, 0, MAX_PHONE_LEN() );
        next if $Seen{$Item}++;
        push @Out, $Item;
        last if @Out >= MAX_PHONES();
    }
    return @Out;
}

1;
