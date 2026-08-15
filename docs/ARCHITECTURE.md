# Arquitetura funcional

Continuidade e manuais oficiais: [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) · [REFERENCES.md](REFERENCES.md) · [FEATURES.md](FEATURES.md)

## Produção

- Servidor: `178.159.34.132`
- Utilizador de administração: `root`
- Instalação OTOBO: `/opt/otobo`
- Código personalizado: `/opt/otobo/Custom`

O acesso ao servidor é feito através da chave privada local do administrador. A chave **não** faz parte deste repositório.

## Domínios funcionais personalizados

### Clientes, lojas e equipas

- Uma empresa cliente pode ter várias lojas; a loja `S - Sede` é criada por defeito.
- Os utilizadores de cliente pertencem a uma loja.
- Os clientes pertencem a um agente responsável.
- Colaboradores podem ter acesso por cliente ou por loja.
- A separação BWB/ZS Angola é aplicada por filas, propriedade de cliente e permissões personalizadas.

### Filas e correio

- `bwb-in`: suporte BWB / StoresAce.
- `zsangola-in`: remetentes ZS Angola reconhecidos na base de dados.
- `zs-postmaster`: remetentes ZS Angola ainda não reconhecidos.
- Encaminhamentos autorizados usam o assunto no formato `CODIGO_CLIENTE | email@cliente | Fwd: título`.

### Folhas de trabalho

- O técnico inicia uma intervenção escolhendo um tipo de intervenção.
- Notas e anexos são guardados como rascunho interno durante o trabalho.
- Ao terminar, escolhe resultado, visibilidade no portal e, opcionalmente, envio por e-mail ao cliente.
- O tempo é calculado automaticamente.

### Convites e palavra-passe

- Convites e reposições usam ligações de utilização única e expiração.
- Não há criação pública de contas no portal.

## Componentes principais

| Área | Código relevante |
|---|---|
| Lojas | `Kernel/System/BWBStore.pm`, `Kernel/Modules/AdminBWBStore.pm` |
| Convites | `Kernel/System/BWBInvite.pm`, `Kernel/Modules/PublicBWBInvite.pm` |
| Folhas de trabalho | `Kernel/System/BWBWorkSession.pm`, `Kernel/System/BWBWorkSheet.pm`, `Kernel/Modules/AgentBWBWorkSession.pm` |
| Tipos de operação/resultados | `BWBOperationType.pm`, `BWBResultType.pm` e respetivos módulos Admin |
| Conversão postmaster | `BWBConvertCustomer.pm`, `AgentBWBConvertCustomer.pm` |
| Regras ZS IMAP | `BWBZSIMAP.pm`, `MailAccount/IMAPSZS.pm`, `PostMaster/Filter/ZSAKnownCustomer.pm` |
| Isolamento de acessos | `BWBAccess.pm`, `Ticket/Permission/BWBCustomerOwnerCheck.pm` |
| E-mail | `Ticket/Event/NotificationEvent/Transport/Email.pm`, templates NotificationEvent |
| Dashboard | `Output/HTML/Dashboard/BWBOpenWork.pm`, configurações `ZZZBWBDashboard*.pm` |
