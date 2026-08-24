from __future__ import annotations

import re

from app.ollama_client import ollama_chat

SYSTEM = """És um assistente técnico do helpdesk StoresAce/BWB.
Responde em português de Portugal.
Usa APENAS os excertos fornecidos. Não inventes procedimentos.
Se os excertos não cobrirem a pergunta, diz explicitamente que não encontraste na base interna.
Cita sempre os números dos artigos (f_number / Ticket#) mencionados.
Se algum excerto indicar «Por validar», avisa que esse conteúdo ainda não está confirmado."""


def _strip_html(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def extractive_summary(question: str, excerpts: list[dict]) -> str:
    if not excerpts:
        return (
            "Não encontrei artigos relevantes na base de conhecimento interna "
            "para essa pergunta. Reformule com termos do produto (ex.: PTcert, EFI, WSL2) "
            "ou consulte a Ajuda."
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
        if body:
            lines.append(f"   {body}")
    lines.append("")
    lines.append("Abra os links na lista abaixo para o procedimento completo. Não execute passos que não estejam no artigo.")
    return "\n".join(lines)


async def synthesize(question: str, excerpts: list[dict]) -> tuple[str, str]:
    """Return (summary, mode) where mode is ollama|extractive."""
    if not excerpts:
        return extractive_summary(question, excerpts), "extractive"

    packed = []
    for item in excerpts[:6]:
        packed.append(
            f"- id={item.get('doc_id')} number={item.get('number')} title={item.get('title')}\n"
            f"  {_strip_html(item.get('excerpt') or item.get('body') or '')[:1200]}"
        )
    user = f"Pergunta do técnico:\n{question}\n\nExcertos autorizados:\n" + "\n".join(packed)
    llm = await ollama_chat(SYSTEM, user)
    if llm and llm.strip():
        return llm.strip(), "ollama"
    return extractive_summary(question, excerpts), "extractive"
