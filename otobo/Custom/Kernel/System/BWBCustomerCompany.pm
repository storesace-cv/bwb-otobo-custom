package Kernel::System::BWBCustomerCompany;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

=head2 ShowAccountedDurationGet()

Returns 1 when the customer should see accounted duration on work sheets
(e-mail and customer portal). Missing rows default to 1 (Sim).

    my $Show = $Object->ShowAccountedDurationGet(
        CustomerID => '1001',   # optional if TicketID is given
        TicketID   => 123,
    );

=cut

sub ShowAccountedDurationGet {
    my ( $Self, %Param ) = @_;

    my $CustomerID = $Param{CustomerID} || '';
    if ( !$CustomerID && $Param{TicketID} ) {
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
            Silent        => 1,
        );
        $CustomerID = $Ticket{CustomerID} || '';
    }
    return 1 if !$CustomerID;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return 1 if !$DBObject->Prepare(
        SQL   => 'SELECT show_accounted_duration FROM bwb_customer_company_setting WHERE customer_id = ?',
        Bind  => [ \$CustomerID ],
        Limit => 1,
    );
    my ($Value) = $DBObject->FetchrowArray();
    return 1 if !defined $Value;
    return $Value ? 1 : 0;
}

=head2 ShowAccountedDurationSet()

Persists the Sim/Não flag for a customer company. Default is Sim (1).

=cut

sub ShowAccountedDurationSet {
    my ( $Self, %Param ) = @_;

    my $CustomerID = $Param{CustomerID} || '';
    if ( !$CustomerID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID to save accounted-duration visibility.',
        );
        return;
    }

    my $Value  = $Param{Value} ? 1 : 0;
    my $UserID = $Param{UserID} ? int( $Param{UserID} ) : 1;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return $DBObject->Do(
        SQL => q{
            INSERT INTO bwb_customer_company_setting
                (customer_id, show_accounted_duration, create_time, create_by, change_time, change_by)
            VALUES (?, ?, UTC_TIMESTAMP(), ?, UTC_TIMESTAMP(), ?)
            ON DUPLICATE KEY UPDATE
                show_accounted_duration = VALUES(show_accounted_duration),
                change_time = UTC_TIMESTAMP(),
                change_by = VALUES(change_by)
        },
        Bind => [ \$CustomerID, \$Value, \$UserID, \$UserID ],
    );
}

=head2 MaybeStripAccountedDuration()

Removes accounted-duration markup from customer-facing HTML or plain text
when the company flag is Não. Agents keep the original article body.

=cut

sub MaybeStripAccountedDuration {
    my ( $Self, %Param ) = @_;

    my $Content = $Param{Content} // '';
    return $Content if $Content eq '';
    return $Content if $Self->ShowAccountedDurationGet(%Param);
    return $Self->AccountedDurationRemove( Content => $Content );
}

=head2 AccountedDurationRemove()

Unconditionally strips the accounted-duration field (label and value) from
HTML or plain text.

=cut

sub AccountedDurationRemove {
    my ( $Self, %Param ) = @_;

    my $Content = $Param{Content} // '';
    return $Content if $Content eq '';

    $Content =~ s{<table\b[^>]*\bBWBAccountedDuration\b[^>]*>.*?</table>}{}gsi;
    $Content =~ s{<tr\b[^>]*>\s*<t[hd]\b[^>]*>\s*Dura(?:ção|cao)\s+contabilizada:.*?</tr>}{}gsi;
    $Content =~ s{^\s*Dura(?:ção|cao)\s+contabilizada:.*$}{}gmi;
    $Content =~ s{Dura(?:ção|cao)\s+contabilizada:\s*\d+\s*minutos}{}gi;

    return $Content;
}

1;
