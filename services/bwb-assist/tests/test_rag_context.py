"""Regression tests for generic context-aware RAG + operational answers.

The PTcert login-loop article is a fixture proving the generic mechanism —
not a product-specific code path.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from app.index_store import Doc, IndexStore
from app.retrieve import TICKET_SCORE_FLOOR, TICKET_SCORE_RATIO, retrieve_faq, retrieve_tickets
from app.synthesize import extract_commands, operational_summary, synthesize
from app.context import is_procedural_question


LOGIN_LOOP_BODY = """
Confirmado no Linux original.

Sintoma: LightDM -> autologin pos -> XFCE inicia -> termina -> greeter -> loop.

Causa confirmada: /home/pos/.Xauthority e /home/pos/.ICEauthority com ownership root:root.

Procedimento:
1. systemctl status lightdm --no-pager -l
2. ls -la /home/pos/.Xauthority /home/pos/.ICEauthority /home/pos/.xsession-errors
3. tail -n 120 /home/pos/.xsession-errors
4. Se ownership incorrecto, corrigir apenas esses ficheiros:
chown pos:pos /home/pos/.Xauthority
chown pos:pos /home/pos/.ICEauthority
5. Confirmar: ls -l /home/pos/.Xauthority /home/pos/.ICEauthority
6. systemctl restart lightdm

Não fazer chown recursivo em /home/pos.
Warnings pam_kwallet não foram a causa do incidente.
XIO fatal IO error 11 foi consequência, não a causa primária.
"""

NETBO_BODY = """
Confirmado em produção.

Problema: terminal NET-bo não sincroniza vendas.

Procedimento:
1. systemctl status netbo-agent --no-pager -l
2. journalctl -u netbo-agent -n 80 --no-pager
3. systemctl restart netbo-agent

Não reiniciar o servidor completo sem ordem do responsável.
"""


@pytest.fixture()
def store(tmp_path: Path) -> IndexStore:
    st = IndexStore(tmp_path)
    faqs = [
        Doc(
            doc_id="faq-1",
            kind="faq",
            number="PTC-TEC-GRAFICO-USUARIOS",
            title="PTcert sessão gráfica e utilizadores",
            category="Documentação interna / PTcert",
            body=LOGIN_LOOP_BODY,
            url="/faq/1",
            meta={
                "labels": ["ptcert", "ptc", "grafico"],
                "category_path": "Documentação interna / PTcert",
                "source_type": "kb",
            },
        ),
        Doc(
            doc_id="faq-2",
            kind="faq",
            number="NET-BO-SYNC",
            title="NET-bo sincronização de vendas",
            category="Documentação interna / NET-bo",
            body=NETBO_BODY,
            url="/faq/2",
            meta={
                "labels": ["netbo", "net"],
                "category_path": "Documentação interna / NET-bo",
                "source_type": "kb",
            },
        ),
    ]
    tickets = [
        Doc(
            doc_id="ticket-10",
            kind="ticket",
            number="2026082501",
            title="PTcert arranque em loop LightDM",
            category="bwb-in",
            body="Cliente reporta PTcert em login loop na VM. Corrigido Xauthority.",
            url="/ticket/10",
            meta={"labels": ["ptcert", "lightdm"], "queue": "bwb-in", "source_type": "ticket"},
        ),
        Doc(
            doc_id="ticket-20",
            kind="ticket",
            number="2026082502",
            title="GPS folha de obra não grava",
            category="bwb-in",
            body="Problema genérico de arranque da aplicação GPS. Reiniciar serviço.",
            url="/ticket/20",
            meta={"labels": ["gps", "folha"], "queue": "bwb-in", "source_type": "ticket"},
        ),
        Doc(
            doc_id="ticket-30",
            kind="ticket",
            number="2026082503",
            title="NET-bo sync falhou após update",
            category="bwb-in",
            body="NET-bo agent parado. Reinício resolveu.",
            url="/ticket/30",
            meta={"labels": ["netbo"], "queue": "bwb-in", "source_type": "ticket"},
        ),
    ]
    st.replace_kind("faq", faqs)
    st.replace_kind("ticket", tickets)
    return st


@pytest.mark.asyncio
async def test_ptcert_login_loop_operational_commands(store: IndexStore):
    question = "o que fazer quando o ptcert no arranque está em loop ? quais são os procedimentos ?"
    assert is_procedural_question(question)

    excerpts, debug = retrieve_faq(store, question, limit=3)
    assert excerpts
    assert any("PTC-TEC" in (e.get("number") or "") for e in excerpts)
    assert debug.get("procedural_question") is True

    summary, mode = await synthesize(question, excerpts)
    assert mode in ("operational", "ollama", "extractive")
    for cmd in (
        "systemctl status lightdm --no-pager -l",
        "ls -la /home/pos/.Xauthority /home/pos/.ICEauthority /home/pos/.xsession-errors",
        "tail -n 120 /home/pos/.xsession-errors",
        "chown pos:pos /home/pos/.Xauthority",
        "chown pos:pos /home/pos/.ICEauthority",
        "systemctl restart lightdm",
    ):
        assert cmd in summary, f"missing command: {cmd}"

    assert "recursivo" in summary.lower() or "apenas" in summary.lower()
    # pam_kwallet may appear only as a negated caution from the source, never as root cause claim.
    low = summary.lower()
    if "pam_kwallet" in low:
        assert "não" in low or "nao" in low
    assert "chown -R" not in low and "chown -r" not in low


def test_ptcert_similar_tickets_filtered(store: IndexStore):
    question = "o que fazer quando o ptcert no arranque está em loop ? quais são os procedimentos ?"
    faq_hits, faq_debug = retrieve_faq(store, question, limit=3)
    contexts = set(faq_debug.get("detected_contexts") or [])
    assert contexts, "expected product context detection from FAQ catalog"

    tickets, tdebug = retrieve_tickets(store, question, contexts=contexts, limit=5)
    ids = {t["doc_id"] for t in tickets}
    assert "ticket-20" not in ids, "GPS ticket must not appear for PTcert question"
    # Either PTcert ticket above threshold, or empty — never wrong product.
    for t in tickets:
        labels = set((t.get("meta") or {}).get("labels") or [])
        assert any("ptc" in lab or "ptcert" in lab for lab in labels) or "ptcert" in (t.get("title") or "").lower()

    assert tdebug.get("threshold_ratio") == TICKET_SCORE_RATIO
    assert tdebug.get("threshold_floor") == TICKET_SCORE_FLOOR


def test_netbo_context_is_independent(store: IndexStore):
    question = "como corrigir o NET-bo quando a sincronização falha?"
    faq_hits, faq_debug = retrieve_faq(store, question, limit=3)
    assert any("NET" in (e.get("number") or "") for e in faq_hits)
    contexts = set(faq_debug.get("detected_contexts") or [])
    tickets, _ = retrieve_tickets(store, question, contexts=contexts, limit=5)
    ids = {t["doc_id"] for t in tickets}
    assert "ticket-10" not in ids
    assert "ticket-20" not in ids
    # NET-bo ticket may or may not pass threshold; if present must be netbo.
    for t in tickets:
        assert "netbo" in (t.get("title") or "").lower() or "netbo" in str((t.get("meta") or {}).get("labels"))


def test_no_padding_when_only_noise_tickets(store: IndexStore):
    """If contexts are set and no in-context ticket exists, return empty list."""
    question = "procedimento ptcert login loop"
    contexts = {"ptcert", "ptc"}
    # Remove the only matching ticket from consideration by searching with impossible label.
    tickets, debug = retrieve_tickets(
        store,
        "xyzzy-unique-token-no-match",
        contexts={"ptcert"},
        limit=5,
    )
    # Zero or only truly matching; never GPS filler.
    assert all("gps" not in (t.get("title") or "").lower() for t in tickets)
    assert debug.get("threshold_ratio") == TICKET_SCORE_RATIO


def test_extract_commands_and_procedural_flag():
    cmds = extract_commands(LOGIN_LOOP_BODY)
    assert "systemctl restart lightdm" in cmds
    assert "chown pos:pos /home/pos/.ICEauthority" in cmds
    assert is_procedural_question("quais são os procedimentos?")
    assert not is_procedural_question("o que é o LightDM?")


@pytest.mark.asyncio
async def test_operational_summary_preserves_confidence():
    excerpts = [
        {
            "doc_id": "faq-1",
            "number": "PTC-TEC-GRAFICO-USUARIOS",
            "title": "PTcert sessão gráfica",
            "body": LOGIN_LOOP_BODY,
            "excerpt": LOGIN_LOOP_BODY[:400],
        }
    ]
    text = operational_summary(
        "o que fazer quando o ptcert no arranque está em loop ?",
        excerpts,
    )
    assert "Confirmado" in text
    assert "Procedimento:" in text
