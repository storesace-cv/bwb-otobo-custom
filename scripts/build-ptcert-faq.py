#!/usr/bin/env python3
"""Build curated PTcert FAQ articles and image assets from the source DOCX files."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import shutil
import unicodedata
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph
from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "db" / "ptcert-content"


CATEGORIES = {
    "operacao": ("Operação e vendas", "Operação diária, vendas, mesas, clientes e fecho de caixa."),
    "configuracao": ("Configuração e administração", "Configuração funcional, utilizadores, produtos e parâmetros do PTcert."),
    "fiscal": ("Fiscalidade e documentos", "Documentos fiscais, séries, SAF-T, Tax-Free, SDR e integrações documentais."),
    "inventario": ("Inventário e stock", "Inventário, stock, taras, embalagens e etiquetas."),
    "equipamentos": ("Equipamentos e periféricos", "Balanças, TPA, gavetas, impressão e outros periféricos."),
    "sistemas": ("Instalação, cópias e recuperação", "Instalação, cópias de segurança, recuperação e manutenção de sistemas."),
    "apps": ("Aplicações e integrações", "Aplicações móveis, dashboard, licenças e integrações externas."),
    "comunicacoes": ("Comunicações e ficheiros", "Acesso remoto, transferência de ficheiros e envio de documentos."),
}


@dataclass(frozen=True)
class ArticleSpec:
    number: str
    title: str
    slug: str
    category: str
    source: str
    keywords: str
    summary: str
    use_when: str
    start_heading: str | None = None
    end_heading: str | None = None


SPECS = [
    ArticleSpec("PTC-LOGIN", "Iniciar sessão no PTcert", "login", "operacao", "2-PT-CERT - User Manual.docx", "login acesso código utilizador password", "Entrar no PTcert com ou sem código de acesso.", "Utilize quando um operador precisa de iniciar sessão ou esclarecer o método de autenticação.", "Login no programa", "Gestão de utilizadores"),
    ArticleSpec("PTC-UTILIZADORES", "Gerir utilizadores", "utilizadores", "configuracao", "2-PT-CERT - User Manual.docx", "utilizadores operadores acesso código permissões", "Criar e manter utilizadores do PTcert.", "Utilize para criar operadores, alterar dados ou configurar o respetivo acesso.", "Gestão de utilizadores", "Gestão de grupos e departamentos"),
    ArticleSpec("PTC-GRUPOS", "Gerir grupos e departamentos", "grupos-departamentos", "configuracao", "2-PT-CERT - User Manual.docx", "grupos departamentos permissões utilizadores", "Configurar grupos e departamentos utilizados no PTcert.", "Utilize quando é necessário organizar utilizadores ou parametrizar permissões por grupo.", "Gestão de grupos e departamentos", "Gestão de familia/sub-familia"),
    ArticleSpec("PTC-FAMILIAS", "Gerir famílias e subfamílias", "familias-subfamilias", "configuracao", "2-PT-CERT - User Manual.docx", "famílias subfamílias produtos artigos", "Organizar os produtos por famílias e subfamílias.", "Utilize ao criar ou reorganizar a estrutura de produtos.", "Gestão de familia/sub-familia", "Gestão de produtos"),
    ArticleSpec("PTC-PRODUTOS", "Gerir produtos, preços e IVA", "produtos-precos-iva", "configuracao", "2-PT-CERT - User Manual.docx", "produtos preço iva peso complementos cozinha excel", "Criar e configurar produtos, preços, impostos e opções de venda.", "Utilize para parametrizar artigos e comportamentos associados no ponto de venda.", "Gestão de produtos", "Como efetuar uma venda"),
    ArticleSpec("PTC-VENDA", "Efetuar uma venda", "efetuar-venda", "operacao", "2-PT-CERT - User Manual.docx", "venda cliente identificado consumidor final", "Registar uma venda com ou sem cliente identificado.", "Utilize como procedimento base de faturação no ponto de venda.", "Como efetuar uma venda", "Como imprimir uma consulta de mesa"),
    ArticleSpec("PTC-CONSULTA-MESA", "Imprimir uma consulta de mesa", "consulta-mesa", "operacao", "2-PT-CERT - User Manual.docx", "consulta mesa imprimir cliente", "Emitir uma consulta da mesa antes da faturação.", "Utilize quando o cliente pede a consulta ou quando é necessário conferir os consumos.", "Como imprimir uma consulta de mesa", "Apuros diários / fecho do dia"),
    ArticleSpec("PTC-APUROS", "Efetuar apuros e fecho do dia", "apuros-fecho-dia", "operacao", "2-PT-CERT - User Manual.docx", "apuro caixa X Z fecho dia contador dinheiro", "Executar os apuros de caixa e o fecho diário.", "Utilize no controlo de caixa, conferência de valores e encerramento do dia.", "Apuros diários / fecho do dia", "Operações diversas"),
    ArticleSpec("PTC-OPERACOES", "Operações de mesa e conta", "operacoes-mesa-conta", "operacao", "2-PT-CERT - User Manual.docx", "mesa conta divisão anulação transferência pagamento separado backup", "Executar operações frequentes sobre mesas, contas e documentos.", "Utilize para dividir contas, transferir mesas, pesquisar produtos, anular ou separar pagamentos.", "Operações diversas", None),
    ArticleSpec("PTC-LICENCAS-APP", "Aplicação de ativação e renovação de licenças", "app-licencas", "apps", "APP LICENÇAS.docx", "app licenças ativar renovar android iphone desktop", "Instalar e configurar a aplicação de licenças PTcert.", "Utilize para ativar ou renovar licenças num computador ou dispositivo móvel."),
    ArticleSpec("PTC-AVENCAS", "Configurar avenças e parqueamento", "avencas-parqueamento", "operacao", "AVENÇAS e Parqueamento.docx", "avenças parqueamento cliente faturar talão áreas", "Configurar e operar avenças e registos de parqueamento.", "Utilize em instalações que gerem clientes avençados ou estacionamento."),
    ArticleSpec("PTC-BALANCA-EPELSA", "Configurar a balança EPELSA XS", "balanca-epelsa-xs", "equipamentos", "Balança EPELSA XS Manual.docx", "balança epelsa xs configuração peso", "Configurar e utilizar uma balança EPELSA XS com o PTcert.", "Utilize na instalação ou diagnóstico desta balança."),
    ArticleSpec("PTC-CARTOES-MESAS", "Escolher entre cartões e mesas", "cartoes-vs-mesas", "operacao", "Cartões vs Mesas.docx", "cartões mesas consumo configuração", "Compreender e configurar os modos de operação por cartões ou mesas.", "Utilize ao definir o fluxo de atendimento do estabelecimento."),
    ArticleSpec("PTC-ETIQUETA-PRECO-KG", "Colocar preço por quilograma nas etiquetas", "etiquetas-preco-kg", "inventario", "Colocar Preço_Kg nas Etiquetas.docx", "etiquetas preço kg quilograma prateleira", "Apresentar corretamente o preço por quilograma nas etiquetas de prateleira.", "Utilize na configuração de etiquetas para produtos vendidos por peso."),
    ArticleSpec("PTC-NOMACHINE-ANDROID", "Instalar o NoMachine no Android", "nomachine-android", "comunicacoes", "Comandos NoMachine Instalacao no Android.docx", "nomachine android remoto acesso instalação", "Instalar e preparar o NoMachine num dispositivo Android.", "Utilize para configurar acesso remoto a partir de Android."),
    ArticleSpec("PTC-ATCUD", "Configurar ATCUD e comunicação de séries", "atcud-series", "fiscal", "Comunicação de Séries.docx", "atcud séries comunicação documentos fiscal", "Configurar a comunicação de séries e o respetivo ATCUD.", "Utilize na preparação fiscal das séries documentais."),
    ArticleSpec("PTC-TAX-FREE", "Configurar e utilizar Tax-Free", "tax-free", "fiscal", "Configuração de Tax-Free.docx", "tax free configuração venda turista", "Configurar e utilizar o processo Tax-Free no PTcert.", "Utilize em vendas elegíveis para reembolso de imposto."),
    ArticleSpec("PTC-PEN-TECNICA", "Criar a PEN técnica", "pen-tecnica", "sistemas", "Criação Pen Técnica.docx", "pen técnica instalação suporte boot", "Preparar a PEN técnica usada em instalação e suporte.", "Utilize antes de intervenções técnicas que exijam arranque ou ferramentas externas."),
    ArticleSpec("PTC-LOGOTIPO-SCREENSAVER", "Definir logótipo e proteção de ecrã", "logotipo-screensaver", "configuracao", "Definir Logotipo _ ScreenSaver.docx", "logótipo screensaver proteção ecrã imagem", "Configurar a identidade visual e a proteção de ecrã do POS.", "Utilize para personalizar a imagem apresentada no terminal."),
    ArticleSpec("PTC-DOCS-EMAIL", "Enviar documentos externos por email", "documentos-externos-email", "comunicacoes", "Envio de documentos externos por email.docx", "email documentos externos envio configuração", "Preparar o envio por email de documentos externos.", "Utilize quando documentos gerados fora do fluxo habitual têm de ser enviados pelo sistema."),
    ArticleSpec("PTC-GAVETAS", "Atribuir gavetas por funcionário", "gavetas-funcionario", "equipamentos", "Gavetas por funcionário.docx", "gaveta funcionário operador caixa", "Configurar gavetas de dinheiro por funcionário.", "Utilize quando diferentes operadores devem trabalhar com gavetas específicas."),
    ArticleSpec("PTC-HARDLOCKS", "Instalar drivers Hardlock em imagens TIB antigas", "drivers-hardlock-tib", "sistemas", "Guia Drivers Hardlocks .TIBs Antigas.docx", "hardlock drivers tp-link mt7601u tib acronis", "Instalar drivers necessários em imagens TIB antigas.", "Utilize ao recuperar equipamentos antigos com problemas de drivers ou hardlocks."),
    ArticleSpec("PTC-INVENTARIO", "Realizar um inventário", "inventario", "inventario", "Guia Inventário.docx", "inventário stock contagem diferenças", "Executar o processo de inventário no PTcert.", "Utilize para contagem, conferência e regularização de existências."),
    ArticleSpec("PTC-INSTALACAO-ACRONIS", "Instalar o PTcert com Acronis e PEN técnica", "instalacao-acronis", "sistemas", "Manual de Instalação Acronis.docx", "instalação acronis pen técnica imagem tib", "Instalar ou repor um sistema PTcert usando Acronis.", "Utilize na preparação ou recuperação completa de um equipamento."),
    ArticleSpec("PTC-REFLASH-DIBAL", "Reflashar balanças Dibal", "reflash-balancas-dibal", "equipamentos", "Procedimento para Reflashar Balanças Dibal.docx", "balança dibal reflash firmware", "Executar o reflash de balanças Dibal.", "Utilize quando uma balança Dibal necessita de reposição de firmware."),
    ArticleSpec("PTC-DASHBOARD-APP", "Instalar e configurar a aplicação Dashboard", "app-dashboard", "apps", "PT-CERT - APP DASHBOARD.docx", "dashboard app android iphone desktop instalação", "Instalar e configurar a aplicação Dashboard do PTcert.", "Utilize para disponibilizar indicadores em computador ou dispositivo móvel."),
    ArticleSpec("PTC-DASHBOARD-CONFIG", "Configurar o acesso ao Dashboard", "dashboard-configuracao", "apps", "PT-CERT - Configurações para usar o Dashboard.docx", "dashboard site licenças password configuração", "Configurar o site e a autenticação usados pelo Dashboard.", "Utilize depois de instalar a aplicação ou quando o acesso falha."),
    ArticleSpec("PTC-INTEGRACAO-FATURAS", "Integrar faturas de software externo", "integracao-faturas-externas", "apps", "PT-CERT - Criação de faturas _ contas através de softwares externos.docx", "integração faturas contas software externo ficheiro cabeçalho linhas rodapé", "Criar faturas e contas no PTcert através de ficheiros de software externo.", "Utilize no desenvolvimento ou configuração de integrações documentais."),
    ArticleSpec("PTC-IPESA-IPX", "Configurar a balança IPESA IPX", "ipesa-ipx", "equipamentos", "PT-CERT - IPESA IPX - CONFIGURAÇÕES - V3.docx", "ipesa ipx balança configuração", "Configurar uma balança IPESA IPX para utilização com o PTcert.", "Utilize durante a instalação ou correção da comunicação com a balança."),
    ArticleSpec("PTC-SDR", "Configurar o regime SDR", "regime-sdr", "fiscal", "PT-CERT_Regime_SDR.docx", "sdr depósito reembolso embalagens artigo zona venda", "Configurar o Sistema de Depósito e Reembolso no PTcert.", "Utilize em estabelecimentos abrangidos pelo regime SDR."),
    ArticleSpec("PTC-RECUPERACAO-EFI", "Recuperar o disco de máquinas POS EFI", "recuperacao-disco-efi", "sistemas", "Recuperação disco EFI.docx", "recuperação disco efi clonezilla arranque pen", "Recuperar e reparar o arranque de máquinas POS EFI.", "Utilize quando uma máquina EFI deixa de arrancar ou necessita de reposição."),
    ArticleSpec("PTC-RECUPERACAO-POS", "Recuperar o disco de máquinas POS", "recuperacao-disco-pos", "sistemas", "Recuperação disco.docx", "recuperação disco pos clonezilla arranque pen", "Recuperar e reparar o arranque de máquinas POS sem EFI.", "Utilize quando um POS convencional deixa de arrancar ou necessita de reposição."),
    ArticleSpec("PTC-SAFT-DIARIO", "Gerar diariamente o SAF-T para uma pasta", "saft-diario-pasta", "fiscal", "SAFT - Geração diária para uma pasta.docx", "saft diário pasta geração automática", "Configurar a geração diária do SAF-T para uma pasta.", "Utilize para automatizar a disponibilização periódica do ficheiro SAF-T."),
    ArticleSpec("PTC-CARTOES-PREPAGOS", "Configurar cartões pré-pagos", "cartoes-prepagos", "operacao", "Sistema para gestão de cartões pré-pagos.docx", "cartões pré-pagos saldo carregamento consumo", "Configurar e utilizar a gestão de cartões pré-pagos.", "Utilize em operações baseadas em carregamento e consumo de saldo."),
    ArticleSpec("PTC-TARAS", "Configurar taras e embalagens", "taras-embalagens", "inventario", "Taras e embalagens.docx", "taras embalagens peso balança produtos", "Configurar taras e embalagens associadas aos produtos.", "Utilize em artigos vendidos por peso com embalagem descontável."),
    ArticleSpec("PTC-DOCUMENTOS", "Documentos de venda, consultas e pedidos", "documentos-venda-consultas", "fiscal", "Template de Documentos.docx", "documentos venda reimpressão consulta mesa pedido anulação", "Consultar os documentos disponíveis e as respetivas utilizações.", "Utilize para escolher o documento correto numa operação de venda ou controlo."),
    ArticleSpec("PTC-TIPOS-DOCUMENTO", "Tipos de documentos e operações", "tipos-documentos-operacoes", "fiscal", "Tipos de documentos e de operações.docx", "tipos documento cliente operação fiscal", "Distinguir tipos de documento e tipos de operação.", "Utilize ao parametrizar ou selecionar documentos para clientes."),
    ArticleSpec("PTC-TPA-USB", "Ativar USB no TPA NewNote", "tpa-newnote-usb", "equipamentos", "TPA NEWNOTE - ATIVAR USB.docx", "tpa newnote usb ativar", "Ativar a ligação USB num TPA NewNote.", "Utilize quando o terminal necessita de comunicar por USB."),
    ArticleSpec("PTC-FICHEIROS-POS", "Transferir ficheiros de e para o POS", "transferir-ficheiros-pos", "comunicacoes", "Transferir ficheiros de e para o POS.docx", "ficheiros pos vpn transferência acesso remoto", "Transferir ficheiros entre o computador de suporte e o POS.", "Utilize em intervenções remotas que exijam copiar ficheiros para ou a partir do terminal."),
]


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-")


def iter_blocks(parent: DocumentObject):
    for child in parent.element.body.iterchildren():
        if child.tag == qn("w:p"):
            yield Paragraph(child, parent)
        elif child.tag == qn("w:tbl"):
            yield Table(child, parent)


def style_heading(paragraph: Paragraph) -> int | None:
    name = unicodedata.normalize("NFKD", paragraph.style.name).encode("ascii", "ignore").decode().lower()
    if name == "title":
        return 2
    match = re.match(r"(?:heading|titulo)\s*(\d+)$", name)
    return min(5, (int(match.group(1)) + 1)) if match else None


def paragraph_text(paragraph: Paragraph) -> str:
    return " ".join(paragraph.text.split())


class ArticleBuilder:
    def __init__(self, spec: ArticleSpec, document: DocumentObject, media_dir: Path):
        self.spec = spec
        self.document = document
        self.media_dir = media_dir
        self.image_number = 0
        self.assets: list[dict] = []
        self.image_tokens: dict[str, tuple[str, int, int]] = {}

    def save_image(self, rel_id: str) -> tuple[str, int, int] | None:
        part = self.document.part.related_parts[rel_id]
        raw = part.blob
        digest = hashlib.sha256(raw).hexdigest()[:12]
        with Image.open(BytesIO(raw)) as image:
            image.load()
            image.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
            width, height = image.size
            if width < 120 and height < 120:
                return None
            if digest in self.image_tokens:
                return self.image_tokens[digest]
            self.image_number += 1
            is_photo = image.mode in {"RGB", "CMYK"} and len(image.getcolors(maxcolors=4097) or []) == 0
            extension = ".jpg" if is_photo else ".png"
            filename = f"PTCERT-{self.spec.slug}-{self.image_number:02d}-{digest}{extension}"
            target = self.media_dir / filename
            if extension == ".jpg":
                image.convert("RGB").save(target, "JPEG", quality=86, optimize=True, progressive=True)
                content_type = "image/jpeg"
            else:
                image.convert("RGBA" if "A" in image.getbands() else "RGB").save(target, "PNG", optimize=True)
                content_type = "image/png"
        token = f"@@PTCERT_IMAGE:{filename}@@"
        self.assets.append({"filename": filename, "path": f"media/{filename}", "content_type": content_type, "token": token})
        self.image_tokens[digest] = (token, width, height)
        return self.image_tokens[digest]

    @staticmethod
    def linkify(value: str) -> str:
        return re.sub(
            r"(https?://[^\s<]+)",
            lambda match: f'<a href="{match.group(1)}">{match.group(1)}</a>',
            value,
        )

    def paragraph_html(self, paragraph: Paragraph) -> str:
        text = paragraph_text(paragraph)
        heading = style_heading(paragraph)
        fragments: list[str] = []
        run_plain_text = "".join(run.text for run in paragraph.runs)
        for run in paragraph.runs:
            run_text = html.escape(run.text).replace("\n", "<br>")
            if run.bold:
                run_text = f"<strong>{run_text}</strong>"
            if run.italic:
                run_text = f"<em>{run_text}</em>"
            if run.underline:
                run_text = f"<u>{run_text}</u>"
            if run_text:
                fragments.append(run_text)
            for blip in run._element.xpath(".//a:blip"):
                rel_id = blip.get(qn("r:embed"))
                if rel_id:
                    image = self.save_image(rel_id)
                    if image:
                        token, width, height = image
                        fragments.append(f'</p><figure class="image"><img src="{token}" width="{width}" height="{height}" alt="Ilustração do procedimento"></figure><p>')
        body = "".join(fragments).strip()
        if text and " ".join(run_plain_text.split()) != text:
            body = self.linkify(html.escape(text))
        if not body and text:
            body = self.linkify(html.escape(text))
        if not body:
            return ""
        if heading:
            clean = re.sub(r"</?p>", "", body)
            return f"<h{heading}>{clean}</h{heading}>"
        return f"<p>{body}</p>"

    @staticmethod
    def table_html(table: Table) -> str:
        rows = []
        for row_index, row in enumerate(table.rows):
            cells = []
            tag = "th" if row_index == 0 else "td"
            for cell in row.cells:
                value = "<br>".join(html.escape(" ".join(p.text.split())) for p in cell.paragraphs if p.text.strip())
                cells.append(f"<{tag}>{value}</{tag}>")
            rows.append("<tr>" + "".join(cells) + "</tr>")
        return "<table><thead>" + rows[0] + "</thead><tbody>" + "".join(rows[1:]) + "</tbody></table>" if rows else ""

    def build(self) -> str:
        active = self.spec.start_heading is None
        output = []
        for block in iter_blocks(self.document):
            if isinstance(block, Paragraph):
                text = paragraph_text(block)
                if self.spec.start_heading and text == self.spec.start_heading:
                    active = True
                if active and self.spec.end_heading and text == self.spec.end_heading:
                    break
                if active:
                    value = self.paragraph_html(block)
                    if value:
                        output.append(value)
            elif active:
                value = self.table_html(block)
                if value:
                    output.append(value)
        return "\n".join(output).replace("<p></p>", "")


def build(source_dir: Path, output_dir: Path) -> None:
    if output_dir.exists():
        shutil.rmtree(output_dir)
    media_dir = output_dir / "media"
    article_dir = output_dir / "articles"
    media_dir.mkdir(parents=True)
    article_dir.mkdir(parents=True)

    documents: dict[str, DocumentObject] = {}
    manifest = {"categories": CATEGORIES, "articles": []}
    for spec in SPECS:
        source_path = source_dir / spec.source
        if not source_path.is_file():
            raise SystemExit(f"Missing source: {source_path}")
        document = documents.setdefault(spec.source, Document(source_path))
        builder = ArticleBuilder(spec, document, media_dir)
        body = builder.build()
        if not re.sub(r"<[^>]+>", "", body).strip():
            raise SystemExit(f"Empty article: {spec.number}")
        article_path = article_dir / f"{spec.number}.html"
        article_path.write_text(body, encoding="utf-8")
        manifest["articles"].append({
            "number": spec.number,
            "name": spec.slug,
            "title": spec.title,
            "category": spec.category,
            "keywords": spec.keywords,
            "summary": f"<p>{html.escape(spec.summary)}</p>",
            "use_when": f"<p>{html.escape(spec.use_when)}</p>",
            "body": f"articles/{spec.number}.html",
            "assets": builder.assets,
            "source": spec.source,
        })
    (output_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(SPECS)} articles; {sum(len(a['assets']) for a in manifest['articles'])} image attachments")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    build(args.source_dir, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
