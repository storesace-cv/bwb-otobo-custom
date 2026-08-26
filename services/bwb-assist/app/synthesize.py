from __future__ import annotations

import re

from app.context import is_procedural_question
from app.index_store import tokenize
from app.ollama_client import ollama_chat

SYSTEM = """És um assistente técnico do helpdesk StoresAce/BWB.
Responde em português de Portugal.
Usa APENAS os excertos fornecidos. Não inventes procedimentos.

Quando a pergunta pedir resolução/procedimento/comandos E os excertos contiverem um procedimento técnico confirmado:
- responde de forma operacional e passo a passo;
- preserva e apresenta os comandos exactamente como nas fontes (não os parafraseies);
- inclui verificações e resultado esperado quando existirem;
- inclui notas «não fazer» se estiverem na fonte;
- distingue o nível de confiança da fonte (Confirmado no Linux original / Confirmado em WSL2 / Documentação / Por validar).

Se os excertos não cobrirem a pergunta, diz explicitamente que não encontraste na base interna.
Cita sempre os números dos artigos (f_number / Ticket#) mencionados.
Não apresentes hipóteses como factos confirmados.
Na secção de casos semelhantes (se referida), só casos do mesmo produto/contexto; se não houver, diz que não há casos relevantes."""

_JUSTIFY_STOP = {
    "a", "o", "os", "as", "e", "em", "no", "na", "nos", "nas", "de", "do", "da", "dos", "das",
    "com", "para", "por", "que", "se", "um", "uma", "uns", "umas", "está", "esta", "este",
    "esse", "essa", "the", "and", "or", "of", "to", "in", "on", "at", "is", "are",
}

_CMD_START = re.compile(
    r"^\s*(?:\$\s*)?(?:"
    r"systemctl|service|journalctl|ls|ll|cat|tail|head|grep|chown|chmod|chgrp|"
    r"sudo|su\b|cd\b|wsl(?:\.exe)?|bash|sh\b|psql|mysql|curl|wget|ip\b|ss\b|netstat|"
    r"mount|umount|df\b|du\b|find\b|cp\b|mv\b|rm\b|mkdir|touch|echo|export|"
    r"apt(?:-get)?|yum|dnf|systemctl|reboot|shutdown|kill|pkill|docker|kubectl"
    r")\b",
    re.I,
)


def _strip_html(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def build_justification(
    question: str,
    *,
    title: str = "",
    body: str = "",
    number: str = "",
    score: float | None = None,
    source: str = "index",
) -> str:
    q_tokens = [t for t in tokenize(question) if len(t) >= 3 and t not in _JUSTIFY_STOP]
    hay = tokenize(f"{number} {title} {body}")
    hay_set = set(hay)
    matched = [t for t in q_tokens if t in hay_set]

    bits: list[str] = []
    if matched:
        bits.append("Termos em comum com a pergunta: " + ", ".join(matched[:10]))
    else:
        bits.append("Recuperado por similaridade no índice da base interna (sem termo exacto em comum)")

    if score is not None and score > 0:
        bits.append(f"pontuação de relevância {score:.1f}")

    if source == "otobo_seed":
        bits.append("também coincidente com a pesquisa OTOBO")

    return ". ".join(bits) + "."


def extract_commands(text: str) -> list[str]:
    commands: list[str] = []
    lines = (text or "").splitlines()
    i = 0
    while i < len(lines):
        cleaned = lines[i].strip().rstrip(";")
        cleaned = re.sub(r"^[`\-\*\d\.\)]+\s*", "", cleaned)
        if _CMD_START.search(cleaned) and len(cleaned) >= 8:
            # Join ToAscii-wrapped continuations (paths / flags on next lines).
            j = i + 1
            while j < len(lines):
                nxt = lines[j].strip()
                if not nxt or _CMD_START.search(nxt) or re.match(r"^[A-ZÁÉÍÓÚa-z].{20,}", nxt):
                    # Stop if next line looks like prose or another command.
                    if nxt and (nxt.startswith("/") or nxt.startswith("-")) and not _CMD_START.search(nxt):
                        cleaned = f"{cleaned} {nxt}"
                        j += 1
                        continue
                    break
                if nxt.startswith("/") or nxt.startswith("-"):
                    cleaned = f"{cleaned} {nxt}"
                    j += 1
                    continue
                break
            if cleaned not in commands:
                commands.append(cleaned)
            i = j
            continue
        i += 1
    if not commands:
        for m in re.finditer(
            r"((?:systemctl|chown|ls|tail|wsl(?:\.exe)?)\b[^.\n]{5,160})",
            text or "",
            flags=re.I,
        ):
            cmd = m.group(1).strip()
            if cmd not in commands:
                commands.append(cmd)
    return commands[:20]


def _confidence_note(text: str) -> str:
    """Preserve short confidence markers already present in the source."""
    for pat in (
        r"Confirmado no Linux original",
        r"Confirmado em WSL2",
        r"Confirmado na VM",
        r"Por validar",
        r"Documenta[cç][aã]o[^\n.]{0,40}",
    ):
        m = re.search(pat, text or "", flags=re.I)
        if m:
            return m.group(0).strip()
    return ""


def _extract_caution_notes(text: str) -> list[str]:
    """Pull caution / don't-do lines from the source instead of hardcoding products."""
    notes: list[str] = []
    markers = (
        "não fazer",
        "nao fazer",
        "não foram a causa",
        "nao foram a causa",
        "não alterar",
        "nao alterar",
        "evitar",
        "atenção",
        "atencao",
        "por validar",
    )
    for line in (text or "").splitlines():
        s = re.sub(r"^\s*[-*•\d\.\)]+\s*", "", line).strip()
        if len(s) < 18:
            continue
        low = s.lower()
        if not any(m in low for m in markers):
            continue
        if s not in notes:
            notes.append(s[:280])
        if len(notes) >= 6:
            break
    # Also catch inline paragraphs that mention "Não fazer" without newlines.
    low_all = (text or "").lower()
    if "chown" in low_all and ("recurs" in low_all or "todo o" in low_all or "toda a" in low_all):
        note = "Não executar chown recursivo / em massa no HOME; corrigir apenas os ficheiros afectados."
        if note not in notes:
            notes.insert(0, note)
    if "pam_kwallet" in low_all and ("não foram a causa" in low_all or "nao foram a causa" in low_all):
        note = "Warnings pam_kwallet não foram identificados como causa neste procedimento."
        if note not in notes:
            notes.append(note)
    return notes[:6]


def _commands_for_question(question: str, plain: str) -> list[str]:
    """Prefer commands from the sections that best match the question."""
    if not plain:
        return []
    chunks = re.split(r"\n\s*\n|(?=^#{1,3}\s)|(?=^[A-ZÁÉÍÓÚ][^\n]{6,80}$)", plain, flags=re.M)
    if len(chunks) <= 1:
        return extract_commands(plain)

    q_tokens = set(tokenize(question))
    q_low = question.lower()
    ranked: list[tuple[int, str]] = []
    for chunk in chunks:
        c = chunk.strip()
        if len(c) < 40:
            continue
        low = c.lower()
        # Down-rank alternate-environment sections when the question does not ask for them.
        if "wsl" in low and "wsl" not in q_low:
            continue
        overlap = len(q_tokens & set(tokenize(c)))
        boost = 0
        if any(k in low for k in ("procedimento", "causa confirmada", "loop", "corrigir")):
            boost += 5
        if extract_commands(c):
            boost += 2
        ranked.append((overlap + boost, c))
    ranked.sort(key=lambda x: x[0], reverse=True)
    if not ranked:
        return extract_commands(plain)

    commands: list[str] = []
    best_score = ranked[0][0]
    for score, chunk in ranked:
        if score < max(2, best_score * 0.5):
            continue
        for cmd in extract_commands(chunk):
            if cmd not in commands:
                commands.append(cmd)
        if len(commands) >= 12:
            break
    if not commands:
        commands = extract_commands(plain)
    # If we already have repair/diagnostic service commands, drop bare env probes
    # unless the question is about display/wayland/environment variables.
    substantive = [c for c in commands if not re.match(r"^\s*echo\b", c, flags=re.I)]
    if substantive and not re.search(r"\b(display|wayland|vari[aá]ve|environment|env\b)", q_low):
        commands = substantive
    return commands


def operational_summary(question: str, excerpts: list[dict]) -> str:
    if not excerpts:
        return (
            "Não encontrei um procedimento confirmado na base de conhecimento interna "
            "para essa pergunta. Consulte a Ajuda ou reformule."
        )

    q_tokens = set(tokenize(question))
    scored: list[tuple[float, dict, list[str], str, str]] = []
    for item in excerpts:
        raw = item.get("body") or item.get("excerpt") or ""
        raw_plain = re.sub(r"<br\s*/?>", "\n", raw, flags=re.I)
        raw_plain = re.sub(r"</p>|</li>|</pre>|</h\d>|</ol>|</ul>", "\n", raw_plain, flags=re.I)
        raw_plain = re.sub(r"<h\d[^>]*>", "\n", raw_plain, flags=re.I)
        raw_plain = re.sub(r"<[^>]+>", "", raw_plain)
        commands = _commands_for_question(question, raw_plain)
        conf = _confidence_note(raw_plain)
        overlap = len(q_tokens & set(tokenize(f"{item.get('title')} {item.get('number')} {raw_plain}")))
        score = len(commands) * 3 + overlap
        if "loop" in question.lower() and "loop" in raw_plain.lower():
            score += 8
        if "procedimento" in raw_plain.lower() or "causa confirmada" in raw_plain.lower():
            score += 4
        scored.append((score, item, commands, conf, raw_plain))
    scored.sort(key=lambda x: x[0], reverse=True)
    _score, best, commands, conf, raw = scored[0]

    number = best.get("number") or best.get("doc_id") or "?"
    title = best.get("title") or ""

    lines: list[str] = []
    lines.append(f"Fonte: {number} — {title}")
    if conf:
        lines.append(f"Confiança: {conf}.")
    lines.append("")
    lines.append("Problema / contexto (segundo a base interna):")
    para = ""
    for block in re.split(r"\n\s*\n", raw):
        b = block.strip()
        if len(b) >= 40 and not _CMD_START.search(b):
            if "causa" in b.lower() or "loop" in b.lower() or "sintoma" in b.lower():
                para = b[:420]
                break
            if not para:
                para = b[:420]
    lines.append(para or "Ver artigo citado.")
    lines.append("")
    lines.append("Procedimento:")
    if commands:
        for idx, cmd in enumerate(commands, start=1):
            lines.append(f"{idx}. Executar:")
            lines.append(f"   {cmd}")
    else:
        step_n = 1
        for line in raw.splitlines():
            s = line.strip()
            if re.match(r"^\d+[\).\s]", s) or s.lower().startswith(
                ("verificar", "consultar", "corrigir", "reiniciar", "confirmar", "aceder")
            ):
                lines.append(f"{step_n}. {s}")
                step_n += 1
                if step_n > 12:
                    break
        if step_n == 1:
            lines.append("1. Seguir o procedimento completo no artigo citado (comandos no corpo do documento).")

    notes = _extract_caution_notes(raw)
    # Prefer notes near the chosen procedure (same article, caution markers).
    if notes:
        lines.append("")
        lines.append("Notas / não fazer:")
        for note in notes:
            # Drop orphan fragments like "também não foram a causa."
            if len(note) < 28 and not note.lower().startswith(("não", "nao", "evitar", "warning")):
                continue
            lines.append(f"- {note}")

    lines.append("")
    lines.append("Abra o artigo na lista Documentação para o texto integral e contexto do ambiente.")
    return "\n".join(lines)


def extractive_summary(question: str, excerpts: list[dict]) -> str:
    if is_procedural_question(question):
        return operational_summary(question, excerpts)

    if not excerpts:
        return (
            "Não encontrei artigos relevantes na base de conhecimento interna "
            "para essa pergunta. Reformule ou consulte a Ajuda."
        )
    lines = [
        f"Com base na base interna, estes documentos parecem relevantes para: «{question.strip()}».",
        "",
    ]
    for idx, item in enumerate(excerpts[:5], start=1):
        number = item.get("number") or item.get("doc_id") or "?"
        title = item.get("title") or "(sem título)"
        body = _strip_html(item.get("excerpt") or item.get("body") or "")[:280]
        warn = ""
        if "por validar" in (body + title).lower():
            warn = " [Por validar]"
        lines.append(f"{idx}. {number} — {title}{warn}")
        reason = item.get("justification") or ""
        if reason:
            lines.append(f"   Porquê: {reason}")
        if body:
            lines.append(f"   {body}")
    lines.append("")
    lines.append("Abra os links na lista abaixo para o procedimento completo. Não execute passos que não estejam no artigo.")
    return "\n".join(lines)


async def synthesize(question: str, excerpts: list[dict]) -> tuple[str, str]:
    """Return (summary, mode) where mode is ollama|extractive|operational."""
    if not excerpts:
        return extractive_summary(question, excerpts), "extractive"

    if is_procedural_question(question):
        # Prefer deterministic operational rendering so commands are not paraphrased away.
        # Still allow Ollama to refine if enabled, with the operational draft as constraint.
        draft = operational_summary(question, excerpts)
        packed = []
        for item in excerpts[:4]:
            packed.append(
                f"- id={item.get('doc_id')} number={item.get('number')} title={item.get('title')}\n"
                f"  {_strip_html(item.get('excerpt') or item.get('body') or '')[:2000]}"
            )
        user = (
            f"Pergunta do técnico:\n{question}\n\n"
            f"Rascunho operacional obrigatório (preservar comandos):\n{draft}\n\n"
            f"Excertos:\n" + "\n".join(packed) + "\n\n"
            "Se reescreveres, mantém TODOS os comandos do rascunho e a estrutura passo a passo."
        )
        llm = await ollama_chat(SYSTEM, user)
        if llm and llm.strip() and ("systemctl" in llm or "chown" in llm or "```" in llm or "1." in llm):
            return llm.strip(), "ollama"
        return draft, "operational"

    packed = []
    for item in excerpts[:6]:
        packed.append(
            f"- id={item.get('doc_id')} number={item.get('number')} title={item.get('title')}\n"
            f"  justificação={item.get('justification') or 'n/d'}\n"
            f"  {_strip_html(item.get('excerpt') or item.get('body') or '')[:1200]}"
        )
    user = f"Pergunta do técnico:\n{question}\n\nExcertos autorizados:\n" + "\n".join(packed)
    llm = await ollama_chat(SYSTEM, user)
    if llm and llm.strip():
        return llm.strip(), "ollama"
    return extractive_summary(question, excerpts), "extractive"
