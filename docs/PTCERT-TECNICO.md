# PTcert técnico — estado confirmado (VM Linux vs WSL2)

**Actualizado em 2026-08-25.** Fonte de continuidade para Cursor/Agent sobre o trabalho PTcert técnico.
Não substitui os manuais operacionais em `db/ptcert-content/` nem a documentação oficial PT-CERT.

Classificação obrigatória em qualquer texto técnico:

| Etiqueta | Significado |
|---|---|
| **Confirmado no Linux original** | Observado/validado na VM Linux do PTcert |
| **Confirmado em WSL2** | Observado/validado na distribuição WSL2 `ptCERT` no Windows |
| **Documentação PT-CERT** | Proveniente da documentação do produto |
| **Por validar** | Hipótese ou trabalho incompleto — **não** tratar como procedimento confirmado |

## Separação obrigatória de ambientes

### A) VM PTcert Linux original

- LightDM + Xubuntu/XFCE + autologin do utilizador `pos`
- Autostart do PTcert; DISPLAY X11
- Ambiente Linux tradicional de POS
- O PTcert **não** arranca num desktop Linux convencional para uso normal: a máquina faz autologin e lança imediatamente o ambiente/aplicação PTcert

### B) PTcert importado para WSL2 (Windows)

- Windows como host; distribuição WSL2 `ptCERT`
- systemd dentro da distribuição; WSLg para interface gráfica
- Aplicação lançada como **root** (não como `pos`)
- **Não** é necessário reproduzir a cadeia LightDM/XFCE da VM original para lançar a aplicação no Windows

Não misturar procedimentos, sintomas ou conclusões entre A e B.

---

## 1. PTcert em WSL2 / Windows — estado 2026-08-25

**Confirmado em WSL2:**

- Implementação funcional após importação do root filesystem da VM PTcert original
- Distribuição WSL: `ptCERT`
- systemd funcional como PID 1
- Ubuntu 18.04.5 LTS (Bionic), arquitectura amd64
- Gambas runtime: `/usr/bin/gbr3` versão **3.14.0**
- Aplicação: `/opt/pos/common/bin/pos` — script/binário Gambas executado por `/usr/bin/env gbr3`
- PostgreSQL funcional; base utilizada pelo POS: `pos`
- Ligação activa da aplicação à BD observada via `pg_stat_activity`
- Serviços activos confirmados: `postgresql`, `memcached`, `ssh`, `smbd`, `meshagent`
- WSLg permite execução gráfica do PTcert
- Execução como root: funcional; como utilizador `pos`: `Access forbidden`
- Locale explícito que elimina o warning inicial:

```text
LANG=en_GB.UTF-8
LANGUAGE=en_GB:en
LC_ALL=en_GB.UTF-8
```

- Pode surgir `X Error: BadAtom (invalid Atom parameter) 5` sem impedir o PTcert de abrir e funcionar

Comando que comprovadamente abriu o PTcert:

```text
wsl.exe -d ptCERT -u root -- bash -ic 'export LANG=en_GB.UTF-8; export LANGUAGE=en_GB:en; export LC_ALL=en_GB.UTF-8; cd /opt/pos/common/bin && ./pos /opt/pos'
```

### Instalador / launcher Windows

- Existe launcher Windows e instalador PowerShell para automatizar instalação e atalho
- Instalador em teste: `C:\ptCERT\Install-ptCERT.ps1`
- Pacotes observados nos testes:
  - `C:\ptCERT\ptCERT-wsl-rootfs.tar` — **6237429760** bytes
  - `C:\ptCERT\ptCERT-wsl-rootfs.tar.7z` — **1429584405** bytes
- Ícone próprio ptCERT para o atalho Windows criado/testado

### Teste de instalação limpa (em curso)

Passos já executados no teste:

1. `wsl --shutdown`
2. `wsl --unregister ptCERT`
3. `wsl --list --verbose` — confirmou ausência de distribuições
4. Início do teste real do instalador PowerShell

**Correcções no `Install-ptCERT.ps1` (parsing PowerShell):** strings com `$service:` têm de usar `${service}:` — por exemplo:

- `Write-Status "Serviço ${service}: active." 'OK'`
- `Write-Status "Serviço ${service}: ${stateText} (código $($state.ExitCode))." 'AVISO'`

O instalador foi regravado em **UTF-8 com BOM** para evitar corrupção de caracteres portugueses (`ServiÃ§o`, `cÃ³digo`).

**Por validar:** o teste integral desta versão corrigida do instalador **ainda deve ser concluído**. Também permanece por validar: USB/impressão/hardlocks/periféricos em WSL2; comportamento em versões diferentes de Windows/WSL; restauro exacto de `hardlock_backup`.

---

## 2. Cadeia de arranque — VM Linux original

**Confirmado no Linux original:**

```text
LightDM
→ autologin do utilizador pos
→ sessão Xubuntu/XFCE
→ /home/pos/.config/autostart/pos.desktop
→ sudo /opt/bin/xfce/startup.sh
→ /opt/pos/common/bin/run_pos_new.sh
→ /opt/pos/common/bin/run_software.sh
→ /opt/pos/common/bin/pos /opt/pos
```

LightDM observado:

```text
autologin-guest=false
autologin-user=pos
autologin-user-timeout=2
```

Sessão: Xubuntu/XFCE (`/usr/share/xsessions/xubuntu.desktop` → `Exec=startxfce4`).

`pos.desktop` (relevante):

```ini
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=PTCERT
Exec=sudo /opt/bin/xfce/startup.sh
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
```

- `startup.sh` — se `run_software` não estiver activo, executa `run_pos_new.sh &`
- `run_pos_new.sh` — preparação do ambiente; termina com `run_software.sh &`
- `run_software.sh` — ciclo de execução; arranca `pos /opt/pos`

---

## 3. Login loop na VM original — RESOLVIDO 2026-08-25

**Confirmado no Linux original** (já **não** está em aberto).

### Sintoma

```text
LightDM → tentativa de autologin pos → sessão inicia → sessão termina
→ greeter → novo autologin → repetição contínua
```

### Causa confirmada

Ownership incorrecto de ficheiros de autoridade da sessão gráfica no HOME de `pos`:

1. `/home/pos/.Xauthority` estava `root:root` `0600`  
   LightDM: `Error writing X authority: Failed to open X authority /home/pos/.Xauthority: Permission denied`  
   Corrigido com `chown pos:pos /home/pos/.Xauthority` — **não bastou sozinho**.
2. `/home/pos/.ICEauthority` estava `root:root` `0600`  
   Em `.xsession-errors`: `xfce4-session: Unable to access file /home/pos/.ICEauthority: Permission denied`  
   Corrigido com `chown pos:pos /home/pos/.ICEauthority`.

Depois: `systemctl restart lightdm` → VM voltou a arrancar normalmente e o PTcert voltou a funcionar.

### Não foram a causa primária

- `XIO: fatal IO error 11 (Resource temporarily unavailable) on X server ":0"` — consequência da queda da sessão/X
- Warnings PAM `pam_kwallet.so` / `pam_kwallet5.so`

### Procedimento canónico de diagnóstico (este sintoma)

1. `systemctl status lightdm --no-pager -l`
2. `ls -la /home/pos/.Xauthority /home/pos/.ICEauthority /home/pos/.xsession-errors`
3. Ambos os ficheiros de authority devem ser `pos:pos` (não `root:root`)
4. `tail -n 120 /home/pos/.xsession-errors`
5. Se `Permission denied` sobre `.Xauthority` ou `.ICEauthority`, corrigir **apenas** os ficheiros afectados:

```bash
chown pos:pos /home/pos/.Xauthority
chown pos:pos /home/pos/.ICEauthority
```

6. Confirmar: `ls -l /home/pos/.Xauthority /home/pos/.ICEauthority`
7. `systemctl restart lightdm`

**Não** fazer alterações indiscriminadas de ownership em `/home/pos`.

O Assistente de Ajuda (RAG) deve apresentar estes comandos literais quando a pergunta for procedural e este artigo for recuperado — ver [FEATURES.md](FEATURES.md) § Assistente.

---

## 4. Base de conhecimento OTOBO

- Árvore: **Documentação interna → PTcert** (FAQ interna / agente)
- Artigos técnicos: `PTC-TEC-*` (Arquitectura técnica), `PTC-WSL2-*` (WSL2)
- Informação **interna**; manter sempre as etiquetas de origem acima
- Conteúdo operacional (39 artigos): este repo `db/ptcert-content/`
- Conteúdo técnico: historicamente repo `bwb-otobo-custom-ptcert`; actualizações de 2026-08-25 também versionadas em `db/ptcert-technical-content/` neste repo quando aplicável

---

## Manutenção

Ao confirmar novos factos: actualizar **este** documento e os artigos FAQ técnicos correspondentes no mesmo trabalho. Não converter *Por validar* em confirmado sem evidência experimental datada.
