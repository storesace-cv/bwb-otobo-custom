# --
# Assistente de pesquisa FAQ / RAG (orquestração OTOBO → host IA 165).
# --
package Kernel::System::BWBAssist;

use strict;
use warnings;
use utf8;

use HTTP::Request;
use JSON::PP;
use LWP::UserAgent;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::BWBAccess',
    'Kernel::System::FAQ',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
);

sub new {
    my ( $Type, %Param ) = @_;
    return bless {}, $Type;
}

sub Enabled {
    my ( $Self, %Param ) = @_;
    my $Config = $Kernel::OM->Get('Kernel::Config');
    return 0 if !( $Config->Get('BWBAssist::Enabled') // 1 );
    return 1;
}

sub _ReadFileLine {
    my ( $Self, $Path ) = @_;
    return '' if !$Path || !-r $Path;
    open my $Fh, '<', $Path or return '';
    local $/;
    my $Content = <$Fh> // '';
    close $Fh;
    $Content =~ s/^\s+|\s+$//g;
    return $Content;
}

sub AssistURL {
    my ( $Self, %Param ) = @_;
    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $URL    = $Config->Get('BWBAssist::URL') || '';
    if ( !$URL ) {
        my $Home = $Config->Get('Home') || '/opt/otobo';
        $URL = $Self->_ReadFileLine( $Config->Get('BWBAssist::URLFile') || "$Home/var/bwb-assist.url" );
    }
    $URL =~ s/\/$//;
    return $URL;
}

sub AssistToken {
    my ( $Self, %Param ) = @_;
    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $Token  = $Config->Get('BWBAssist::BearerToken') || '';
    if ( !$Token ) {
        my $Home = $Config->Get('Home') || '/opt/otobo';
        $Token = $Self->_ReadFileLine(
            $Config->Get('BWBAssist::TokenFile') || "$Home/var/bwb-assist.token"
        );
    }
    return $Token;
}

sub _StripHTML {
    my ( $Self, $HTML ) = @_;
    return '' if !defined $HTML || $HTML eq '';
    return $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii( String => $HTML );
}

sub CategoryIDsForAssist {
    my ( $Self, %Param ) = @_;
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');
    my $UserID    = $Param{UserID} || 1;

    # Production root: Documentação interna (id 16) — Helpdesk + PTcert.
    my $RootID = $Kernel::OM->Get('Kernel::Config')->Get('BWBAssist::FAQRootCategoryID') || 16;
    my @IDs    = ($RootID);
    my $SubRef = $FAQObject->CategorySubCategoryIDList(
        ParentID => $RootID,
        Mode     => 'Agent',
        UserID   => $UserID,
    );
    if ( $SubRef && ref $SubRef eq 'ARRAY' ) {
        push @IDs, @{$SubRef};
    }
    return \@IDs;
}

sub _InternalFAQSearchParams {
    my ( $Self, %Param ) = @_;
    my $UserID    = $Param{UserID} || 1;
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');
    my $Config    = $Kernel::OM->Get('Kernel::Config');

    my $Interface = $FAQObject->StateTypeGet(
        Name   => 'internal',
        UserID => $UserID,
    );
    my $Types = $Config->Get('FAQ::Agent::StateTypes') || ['internal'];
    my $States = $FAQObject->StateTypeList(
        Types  => $Types,
        UserID => $UserID,
    );
    return {
        Interface => $Interface,
        States    => $States,
    };
}

sub _FAQSearchWhatTokens {
    my ( $Self, $Query ) = @_;
    return '' if !defined $Query || $Query eq '';

    # FAQSearch What uses AND across tokens — drop Portuguese stop-words that
    # empty results for natural-language questions (e.g. «está», «no», «em»).
    my %Stop = map { $_ => 1 } qw(
        a ao aos as com da das de do dos e em o os ou para por que se um uma
        no na nos nas dum duma dumuns dumas este esta estes estas esse essa
        esses essas aquele aquela aqueles aquelas isto isso aquilo
        está esta estou estamos estão ser estar foi foram
        the and or of to in on at is are was were be been
    );

    my @Tokens;
    for my $Raw ( split /\s+/, $Query ) {
        my $Token = lc $Raw;
        $Token =~ s/[^\p{L}\p{N}\/\.\-_]+//g;
        next if $Token eq '' || length($Token) < 3;
        next if $Stop{$Token};
        push @Tokens, $Token;
    }
    return join( ' ', @Tokens );
}

sub FAQHitsSearch {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID} || !defined $Param{Query} || $Param{Query} eq '';

    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');
    my $Limit     = $Param{Limit} || 8;
    my $Query     = $Param{Query};
    $Query =~ s/^\s+|\s+$//g;

    my $What = $Self->_FAQSearchWhatTokens($Query);
    $What ||= $Query;

    my $SearchBase = $Self->_InternalFAQSearchParams( UserID => $Param{UserID} );
    my %Search     = (
        What             => $What,
        Limit            => $Limit * 3,
        UserID           => $Param{UserID},
        Interface        => $SearchBase->{Interface},
        States           => $SearchBase->{States},
        OrderBy          => ['Changed'],
        OrderByDirection => ['Down'],
    );

    my $CategoryIDs = $Self->CategoryIDsForAssist( UserID => $Param{UserID} );
    $Search{CategoryIDs} = $CategoryIDs if $CategoryIDs && @{$CategoryIDs};

    my @IDs = $FAQObject->FAQSearch(%Search);
    if ( !@IDs && $CategoryIDs ) {
        delete $Search{CategoryIDs};
        @IDs = $FAQObject->FAQSearch(%Search);
    }

    # Fallback: OR-merge searches for the strongest tokens (ptcert, arranque, …).
    if ( !@IDs ) {
        my %Seen;
        for my $Token ( split /\s+/, $What ) {
            next if length($Token) < 4;
            my @Part = $FAQObject->FAQSearch(
                What             => $Token,
                Limit            => $Limit,
                UserID           => $Param{UserID},
                Interface        => $SearchBase->{Interface},
                States           => $SearchBase->{States},
                OrderBy          => ['Changed'],
                OrderByDirection => ['Down'],
                ( $CategoryIDs && @{$CategoryIDs} ? ( CategoryIDs => $CategoryIDs ) : () ),
            );
            for my $ID (@Part) {
                next if $Seen{$ID}++;
                push @IDs, $ID;
                last if scalar @IDs >= $Limit * 3;
            }
        }
    }

    my @Hits;
    my $Config = $Kernel::OM->Get('Kernel::Config');
    my $HttpType = $Config->Get('HttpType') || 'https';
    my $FQDN     = $Config->Get('FQDN')     || '';
    my $Script   = $Config->Get('ScriptAlias') || 'otobo/';

    ID:
    for my $ItemID (@IDs) {
        last ID if scalar @Hits >= $Limit;
        my %FAQ = $FAQObject->FAQGet(
            ItemID     => $ItemID,
            ItemFields => 1,
            UserID     => $Param{UserID},
        );
        next ID if !%FAQ;
        next ID if ( $FAQ{StateTypeName} // '' ) ne 'internal' && ( $FAQ{State} // '' ) !~ /internal/i;

        my $Body = join(
            "\n",
            map { $Self->_StripHTML( $FAQ{$_} // '' ) }
                qw(Field1 Field2 Field3 Field4 Field5 Field6)
        );
        my $URL = '';
        if ($FQDN) {
            $URL = "$HttpType://$FQDN/${Script}index.pl?Action=AgentFAQZoom;ItemID=$ItemID";
        }
        push @Hits, {
            doc_id   => "faq-$ItemID",
            kind     => 'faq',
            item_id  => $ItemID,
            number   => $FAQ{Number} || '',
            title    => $FAQ{Title}  || '',
            category => $FAQ{CategoryName} || '',
            excerpt  => substr( $Body, 0, 800 ),
            body     => substr( $Body, 0, 4000 ),
            url      => $URL,
            meta     => {
                keywords => $FAQ{Keywords} || '',
                state    => $FAQ{State}    || '',
            },
        };
    }
    return \@Hits;
}

sub HTTPJSON {
    my ( $Self, %Param ) = @_;
    my $URL   = $Param{URL}   || $Self->AssistURL();
    my $Token = $Param{Token} || $Self->AssistToken();
    my $Path  = $Param{Path}  || '';
    return { ok => 0, error => 'assist_url_missing' } if !$URL;
    return { ok => 0, error => 'assist_token_missing' } if !$Token;

    my $Timeout = $Kernel::OM->Get('Kernel::Config')->Get('BWBAssist::Timeout') || 45;
    my $UA      = LWP::UserAgent->new(
        timeout => $Timeout,
        agent   => 'BWBAssist/1.0',
    );
    my $JSON = JSON::PP->new->utf8->canonical;
    my $Req  = HTTP::Request->new( $Param{Method} || 'POST', "$URL$Path" );
    $Req->header( 'Authorization' => "Bearer $Token" );
    $Req->header( 'Content-Type'  => 'application/json; charset=utf-8' );
    if ( $Param{Body} ) {
        $Req->content( $JSON->encode( $Param{Body} ) );
    }

    my $Res = $UA->request($Req);
    if ( !$Res->is_success ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "BWBAssist HTTP " . $Res->code . " $Path: " . substr( $Res->decoded_content // '', 0, 200 ),
        );
        return {
            ok     => 0,
            error  => 'assist_http_' . $Res->code,
            status => $Res->code,
        };
    }
    my $Data;
    eval {
        $Data = $JSON->decode( $Res->decoded_content );
        1;
    } or do {
        return { ok => 0, error => 'assist_bad_json' };
    };
    return $Data;
}

sub AssistFAQ {
    my ( $Self, %Param ) = @_;
    return { ok => 0, error => 'disabled', unavailable => 1 } if !$Self->Enabled();
    return { ok => 0, error => 'need_userid_query', unavailable => 1 }
        if !$Param{UserID} || !defined $Param{Query} || $Param{Query} eq '';

    my $Hits = $Self->FAQHitsSearch(
        UserID => $Param{UserID},
        Query  => $Param{Query},
        Limit  => $Param{Limit} || 5,
    );

    my $Remote = $Self->HTTPJSON(
        Path => '/v1/assist/faq',
        Body => {
            question  => $Param{Query},
            excerpts  => $Hits,
            limit     => $Param{Limit} || 5,
            use_index => JSON::PP::true,
        },
    );

    if ( !$Remote->{ok} ) {

        # Sem IA o Assistente não degrada para pesquisa OTOBO — evita resultados enganadores.
        return {
            ok          => 0,
            unavailable => 1,
            error       => $Remote->{error} || 'assist_unavailable',
            mode        => 'unavailable',
            summary     => '',
            excerpts    => [],
            tickets     => [],
            message     => $Self->_UnavailableMessage( $Remote->{error} ),
        };
    }

    # Prefer OTOBO-authorized FAQ hits for display; merge remote extras only if already in local set or faq-*.
    my %LocalByID = map { $_->{doc_id} => $_ } @{$Hits};
    my @Display;
    for my $Ex ( @{ $Remote->{excerpts} || [] } ) {
        my $ID = $Ex->{doc_id} // '';
        my $Justification = $Ex->{justification} || '';
        if ( $LocalByID{$ID} ) {
            my %Row = %{ $LocalByID{$ID} };
            $Row{justification} = $Justification if $Justification;
            $Row{excerpt}       = $Ex->{excerpt} if $Ex->{excerpt};
            push @Display, \%Row;
        }
        elsif ( $ID =~ /^faq-(\d+)$/ ) {
            my $ItemID = $1;
            my %FAQ    = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
                ItemID     => $ItemID,
                ItemFields => 1,
                UserID     => $Param{UserID},
            );
            next if !%FAQ;
            push @Display, {
                doc_id         => $ID,
                kind           => 'faq',
                item_id        => $ItemID,
                number         => $FAQ{Number} || $Ex->{number},
                title          => $FAQ{Title}  || $Ex->{title},
                category       => $FAQ{CategoryName} || $Ex->{category},
                excerpt        => $Ex->{excerpt} || '',
                url            => $Ex->{url} || '',
                justification  => $Justification,
                meta           => $Ex->{meta} || {},
            };
        }
    }

    return {
        ok            => 1,
        unavailable   => 0,
        mode          => $Remote->{mode} || 'unknown',
        summary       => $Remote->{summary} || '',
        excerpts      => \@Display,
        cited_ids     => $Remote->{cited_ids} || [],
    };
}

sub _UnavailableMessage {
    my ( $Self, $Error ) = @_;
    my $Detail = '';
    if ( $Error && $Error ne 'assist_unavailable' ) {
        $Detail = " (código técnico: $Error)";
    }
    return
        "O Assistente de Ajuda não está disponível neste momento$Detail. "
        . "Esta função depende do serviço de IA; sem ele não apresenta resultados, "
        . "para não confundir com a pesquisa normal. Use o menu Ajuda "
        . "(pesquisa standard do OTOBO) até o serviço voltar.";
}

sub SearchRemote {
    my ( $Self, %Param ) = @_;
    return { ok => 0, error => 'disabled' } if !$Self->Enabled();
    my %Body = (
        question => $Param{Query},
        kinds    => $Param{Kinds} || ['faq'],
        limit    => $Param{Limit} || 8,
    );
    if ( $Param{Contexts} && ref $Param{Contexts} eq 'ARRAY' ) {
        $Body{contexts} = $Param{Contexts};
    }
    return $Self->HTTPJSON(
        Path => '/v1/assist/search',
        Body => \%Body,
    );
}

sub _ContextLabelsFromText {
    my ( $Self, @Parts ) = @_;
    my %Seen;
    my @Labels;
    for my $Part (@Parts) {
        next if !defined $Part || $Part eq '';
        # Hierarchy / code separators only — avoid dumping every prose word.
        for my $Token ( split /[\s\>\/\|\-_,;:]+/, $Part ) {
            $Token =~ s/^\s+|\s+$//g;
            next if length($Token) < 4;
            my $Norm = lc $Token;
            $Norm =~ s/[^a-z0-9]+//g;
            next if length($Norm) < 4 || length($Norm) > 16;
            next if $Seen{$Norm}++;
            push @Labels, $Norm;
        }
    }
    return \@Labels;
}

sub FilterTicketHitsForUser {
    my ( $Self, %Param ) = @_;
    return [] if !$Param{UserID} || !$Param{Hits};
    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    my @Out;
    for my $Hit ( @{ $Param{Hits} } ) {
        my $TicketID = $Hit->{meta}{ticket_id} || $Hit->{ticket_id} || 0;
        if ( !$TicketID && ( $Hit->{doc_id} // '' ) =~ /^ticket-(\d+)$/ ) {
            $TicketID = $1;
        }
        next if !$TicketID;
        next
            if !$Access->TicketAccessCheck(
            UserID   => $Param{UserID},
            TicketID => $TicketID,
            );
        $Hit->{ticket_id} = $TicketID;
        push @Out, $Hit;
    }
    return \@Out;
}

sub AssistWithTickets {
    my ( $Self, %Param ) = @_;
    return { ok => 0, error => 'disabled', unavailable => 1 } if !$Self->Enabled();
    return { ok => 0, error => 'need_userid_query', unavailable => 1 }
        if !$Param{UserID} || !defined $Param{Query} || $Param{Query} eq '';

    my $Hits = $Self->FAQHitsSearch(
        UserID => $Param{UserID},
        Query  => $Param{Query},
        Limit  => $Param{Limit} || 5,
    );

    # Combined FAQ + tickets: shared context detection and ticket thresholds on 165.
    my $Remote = $Self->HTTPJSON(
        Path => '/v1/assist/query',
        Body => {
            question     => $Param{Query},
            excerpts     => $Hits,
            faq_limit    => $Param{Limit}       || 5,
            ticket_limit => $Param{TicketLimit} || 5,
            use_index    => JSON::PP::true,
        },
    );

    if ( !$Remote->{ok} ) {
        return {
            ok          => 0,
            unavailable => 1,
            error       => $Remote->{error} || 'assist_unavailable',
            mode        => 'unavailable',
            summary     => '',
            excerpts    => [],
            tickets     => [],
            message     => $Self->_UnavailableMessage( $Remote->{error} ),
        };
    }

    my %LocalByID = map { $_->{doc_id} => $_ } @{$Hits};
    my @Display;
    for my $Ex ( @{ $Remote->{excerpts} || [] } ) {
        my $ID            = $Ex->{doc_id} // '';
        my $Justification = $Ex->{justification} || '';
        if ( $LocalByID{$ID} ) {
            my %Row = %{ $LocalByID{$ID} };
            $Row{justification} = $Justification if $Justification;
            $Row{excerpt}       = $Ex->{excerpt} if $Ex->{excerpt};
            push @Display, \%Row;
        }
        elsif ( $ID =~ /^faq-(\d+)$/ ) {
            my $ItemID = $1;
            my %FAQ    = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
                ItemID     => $ItemID,
                ItemFields => 1,
                UserID     => $Param{UserID},
            );
            next if !%FAQ;
            push @Display, {
                doc_id        => $ID,
                kind          => 'faq',
                item_id       => $ItemID,
                number        => $FAQ{Number}       || $Ex->{number},
                title         => $FAQ{Title}        || $Ex->{title},
                category      => $FAQ{CategoryName} || $Ex->{category},
                excerpt       => $Ex->{excerpt}     || '',
                url           => $Ex->{url}         || '',
                justification => $Justification,
                meta          => $Ex->{meta} || {},
            };
        }
    }

    my $TicketHits = $Self->FilterTicketHitsForUser(
        UserID => $Param{UserID},
        Hits   => $Remote->{tickets} || [],
    );
    for my $Hit ( @{$TicketHits} ) {
        $Hit->{justification} ||= '';
    }

    return {
        ok          => 1,
        unavailable => 0,
        mode        => $Remote->{mode} || 'unknown',
        summary     => $Remote->{summary} || '',
        excerpts    => \@Display,
        tickets     => $TicketHits,
        cited_ids   => $Remote->{cited_ids} || [],

        # Debug stays server-side / JSON API only when explicitly requested.
        ( $Param{IncludeDebug} ? ( debug => $Remote->{debug} || {} ) : () ),
    };
}

sub SuggestFromTicket {
    my ( $Self, %Param ) = @_;
    return { ok => 0, error => 'need_ticket' } if !$Param{UserID} || !$Param{TicketID};

    my $Access = $Kernel::OM->Get('Kernel::System::BWBAccess');
    if (
        !$Access->TicketAccessCheck(
            UserID   => $Param{UserID},
            TicketID => $Param{TicketID},
        )
        )
    {
        return { ok => 0, error => 'forbidden' };
    }

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );
    return { ok => 0, error => 'ticket_not_found' } if !%Ticket;

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my @ArticleIDs    = $ArticleObject->ArticleList(
        TicketID => $Param{TicketID},
    );
    my @Texts = ( $Ticket{Title} || '' );
    my $Count = 0;
    for my $Meta ( reverse @ArticleIDs ) {
        last if $Count >= 3;
        my $Backend = $ArticleObject->BackendForArticle(
            TicketID  => $Param{TicketID},
            ArticleID => $Meta->{ArticleID},
        );
        my %Article = $Backend->ArticleGet(
            TicketID  => $Param{TicketID},
            ArticleID => $Meta->{ArticleID},
            UserID    => $Param{UserID},
        );
        my $Body = $Self->_StripHTML( $Article{Body} // '' );
        push @Texts, substr( $Body, 0, 1500 ) if $Body;
        $Count++;
    }
    my $Query = join( "\n", grep { $_ ne '' } @Texts );
    $Query = substr( $Query, 0, 1800 );
    return $Self->AssistWithTickets(
        UserID => $Param{UserID},
        Query  => $Query,
        Limit  => $Param{Limit} || 5,
    );
}

sub IndexFAQDocs {
    my ( $Self, %Param ) = @_;
    my $UserID      = $Param{UserID} || 1;
    my $FAQObject   = $Kernel::OM->Get('Kernel::System::FAQ');
    my $CategoryIDs = $Self->CategoryIDsForAssist( UserID => $UserID );
    my $SearchBase  = $Self->_InternalFAQSearchParams( UserID => $UserID );
    my @IDs         = $FAQObject->FAQSearch(
        Limit       => 500,
        UserID      => $UserID,
        Interface   => $SearchBase->{Interface},
        States      => $SearchBase->{States},
        CategoryIDs => $CategoryIDs,
    );
    if ( !@IDs ) {
        @IDs = $FAQObject->FAQSearch(
            Limit     => 500,
            UserID    => $UserID,
            Interface => $SearchBase->{Interface},
            States    => $SearchBase->{States},
        );
    }
    my $Config   = $Kernel::OM->Get('Kernel::Config');
    my $HttpType = $Config->Get('HttpType') || 'https';
    my $FQDN     = $Config->Get('FQDN')     || 'helpdesk.storesace.cv';
    my $Script   = $Config->Get('ScriptAlias') || 'otobo/';
    my @Docs;
    for my $ItemID (@IDs) {
        my %FAQ = $FAQObject->FAQGet(
            ItemID     => $ItemID,
            ItemFields => 1,
            UserID     => $UserID,
        );
        next if !%FAQ;
        my $Body = join(
            "\n",
            map { $Self->_StripHTML( $FAQ{$_} // '' ) }
                qw(Field1 Field2 Field3 Field4 Field5 Field6)
        );

        # Keep troubleshooting articles as one semantic unit (symptom+cause+procedure+commands).
        my $CategoryPath = $FAQ{CategoryName} || '';
        my $Labels       = $Self->_ContextLabelsFromText(
            $FAQ{Number} || '',
            $CategoryPath,
            $FAQ{Title}    || '',
            $FAQ{Keywords} || '',
        );
        push @Docs, {
            doc_id   => "faq-$ItemID",
            id       => "faq-$ItemID",
            number   => $FAQ{Number} || '',
            title    => $FAQ{Title}  || '',
            category => $CategoryPath,
            body     => substr( $Body, 0, 15000 ),
            url      => "$HttpType://$FQDN/${Script}index.pl?Action=AgentFAQZoom;ItemID=$ItemID",
            meta     => {
                item_id       => $ItemID,
                keywords      => $FAQ{Keywords} || '',
                category_path => $CategoryPath,
                labels        => $Labels,
                source_type   => 'kb',
            },
        };
    }
    return \@Docs;
}

sub IndexClosedTicketDocs {
    my ( $Self, %Param ) = @_;
    my $UserID       = $Param{UserID} || 1;
    my $Limit        = $Param{Limit}  || 300;
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    my @TicketIDs = $TicketObject->TicketSearch(
        Result    => 'ARRAY',
        StateType => ['closed'],
        Limit     => $Limit,
        UserID    => $UserID,
        Permission => 'ro',
    );

    my $Config   = $Kernel::OM->Get('Kernel::Config');
    my $HttpType = $Config->Get('HttpType') || 'https';
    my $FQDN     = $Config->Get('FQDN')     || 'helpdesk.storesace.cv';
    my $Script   = $Config->Get('ScriptAlias') || 'otobo/';

    my @Docs;
    for my $TicketID (@TicketIDs) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            UserID        => $UserID,
            DynamicFields => 0,
        );
        next if !%Ticket;

        my $Domain = 'bwb';
        my $Queue  = $Ticket{Queue} // '';
        if ( $Queue eq 'zsangola-in' || $Queue eq 'zs-postmaster' ) {
            $Domain = 'zs';
        }

        my @ArticleMeta = $ArticleObject->ArticleList( TicketID => $TicketID );
        my @Bodies;
        my $Count = 0;
        for my $Meta (@ArticleMeta) {
            last if $Count >= 4;
            my $Backend = $ArticleObject->BackendForArticle(
                TicketID  => $TicketID,
                ArticleID => $Meta->{ArticleID},
            );
            my %Article = $Backend->ArticleGet(
                TicketID  => $TicketID,
                ArticleID => $Meta->{ArticleID},
                UserID    => $UserID,
            );
            my $Body = $Self->_StripHTML( $Article{Body} // '' );
            next if $Body eq '';
            push @Bodies, substr( $Body, 0, 2000 );
            $Count++;
        }

        my $Service = $Ticket{Service} || '';
        my $Type    = $Ticket{Type}    || '';
        # Labels only from structured fields + title — never full article body (noise).
        my $Labels  = $Self->_ContextLabelsFromText(
            $Ticket{Title} || '',
            $Service,
            $Type,
        );
        push @Docs, {
            doc_id   => "ticket-$TicketID",
            id       => "ticket-$TicketID",
            number   => $Ticket{TicketNumber} || '',
            title    => $Ticket{Title} || '',
            category => $Queue,
            body     => substr( join( "\n", $Ticket{Title} || '', @Bodies ), 0, 12000 ),
            url      => "$HttpType://$FQDN/${Script}index.pl?Action=AgentTicketZoom;TicketID=$TicketID",
            meta     => {
                ticket_id     => $TicketID,
                customer_id   => $Ticket{CustomerID} || '',
                queue         => $Queue,
                service       => $Service,
                type          => $Type,
                domain        => $Domain,
                labels        => $Labels,
                source_type   => 'ticket',
                category_path => join( ' / ', grep { $_ ne '' } ( $Queue, $Service, $Type ) ),
            },
        };
    }
    return \@Docs;
}

1;
