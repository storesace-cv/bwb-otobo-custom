-- Manuais Ajuda: GPS na folha + tickets/calendário.
-- Idempotente: INSERT se novo; UPDATE se f_number já existir.
-- Reversão: DELETE FROM faq_item WHERE f_number IN ('HD-GPS-FOLHA','HD-TICKETS-CALENDARIO');

SET NAMES utf8mb4;

-- HD-GPS-FOLHA
INSERT INTO faq_item (
  f_number, f_name, f_subject, f_language_id, state_id, category_id,
  approved, valid_id, content_type, f_keywords,
  f_field1, f_field2, f_field3, f_field6,
  created, created_by, changed, changed_by
)
SELECT
  'HD-GPS-FOLHA',
  'manual-folha-gps',
  'Localização GPS ao terminar a folha de trabalho',
  3, 2,
  21,
  1, 1, 'text/html',
  'gps localização folha trabalho terminar mapa loja field mode',
  '<p>Registar onde estava ao <strong>terminar uma folha de trabalho</strong>, com mapa interno no ticket (só agentes).</p>',
  '<p>Utilize quando precisa de perceber como funciona o pedido de localização ao carregar em <strong>Terminar trabalho</strong> (computador ou telemóvel).</p>',
  '<h2>Para que serve</h2>
<p>Ao <strong>terminar uma folha de trabalho</strong>, o helpdesk regista <strong>onde estava</strong> nesse momento. Isto ajuda a confirmar intervenções no terreno (loja, cliente, etc.).</p>
<p>A localização <strong>nunca impede</strong> fechar a folha: se o GPS falhar, o sistema usa alternativas ou fecha na mesma, com uma nota interna.</p>
<h2>Quando é pedida</h2>
<p>Só ao carregar em <strong>Terminar trabalho</strong>, depois de preencher resultado, visibilidade no portal, envio de e-mail (se aplicável) e outros campos do resultado (por exemplo agendamento).</p>
<p><strong>Não</strong> é pedida ao iniciar, pausar ou guardar rascunho.</p>
<h2>O que acontece ao carregar «Terminar trabalho»</h2>
<ol>
<li>O botão mostra <strong>«A obter localização…»</strong> e fica temporariamente inactivo.</li>
<li>O <strong>navegador</strong> pode pedir permissão — convém escolher <strong>Permitir</strong>.</li>
<li>O sistema tenta obter o GPS (até cerca de 15 segundos).</li>
<li>De seguida a folha <strong>fecha normalmente</strong>, com ou sem GPS.</li>
</ol>
<h2>Três cenários possíveis</h2>
<table>
<thead><tr><th>Situação</th><th>O que fica registado</th><th>O que vê depois no ticket</th></tr></thead>
<tbody>
<tr><td><strong>GPS OK</strong></td><td>Coordenadas do telemóvel ou computador, com precisão aproximada</td><td>Mapa com a posição real no fecho</td></tr>
<tr><td><strong>GPS indisponível</strong>, mas a loja do ticket tem coordenadas</td><td>Coordenadas <strong>da loja</strong> (alternativa automática)</td><td>Mapa na loja e nota interna a indicar que o GPS falhou</td></tr>
<tr><td><strong>GPS indisponível</strong> e loja sem coordenadas</td><td>Sem mapa; nota interna no registo</td><td>Folha fechada; <strong>sem</strong> secção de mapa</td></tr>
</tbody>
</table>
<h2>Onde ver o mapa</h2>
<ul>
<li>Só na interface de <strong>agente</strong>, no detalhe do ticket, <strong>abaixo da folha de trabalho</strong> fechada.</li>
<li>Aparece a secção <strong>«Mapa da localização»</strong> (Google Maps, vista satélite), com coordenadas e ligação <strong>«Abrir no Google Maps»</strong>.</li>
<li>O <strong>cliente não vê o mapa</strong> no portal nem no e-mail da folha — é informação interna do helpdesk.</li>
</ul>
<h2>Boas práticas no terreno</h2>
<ol>
<li>Permitir localização no browser (Chrome, Safari, etc.) para o site do helpdesk.</li>
<li>No telemóvel, activar GPS/localização do sistema operativo.</li>
<li>Terminar a folha <strong>no local da intervenção</strong>, não horas depois noutro sítio.</li>
<li>Confirmar que o ticket tem a <strong>loja correcta</strong> (menu «Alterar loja» no ticket) — serve de alternativa se o GPS falhar.</li>
<li>Se a loja não tiver coordenadas, peça à administração para as registar (útil em armazéns ou caves onde o GPS falha).</li>
</ol>
<h2>Field Mode (técnico no telemóvel)</h2>
<p>O comportamento é o <strong>mesmo</strong>: ao tocar <strong>Terminar trabalho</strong>, o telemóvel pede localização. Use Safari ou Chrome com permissões activas; em iPhone/iPad confirme que o site do helpdesk pode usar «Localização».</p>
<h2>Perguntas frequentes</h2>
<p><strong>Tenho de aceitar o GPS para fechar a folha?</strong><br>Não. Recusar ou falhar o GPS <strong>não impede</strong> terminar o trabalho.</p>
<p><strong>Demora muito?</strong><br>Normalmente poucos segundos; no máximo cerca de 15 segundos de espera.</p>
<p><strong>Porque aparece a loja e não o sítio onde estou?</strong><br>O GPS falhou ou foi recusado; o sistema usou as coordenadas da loja associada ao ticket.</p>
<p><strong>Porque não vejo mapa nenhum?</strong><br>Não houve GPS <strong>e</strong> a loja não tem coordenadas registadas.</p>
<p><strong>O mapa não carrega?</strong><br>Reporte à administração; as coordenadas podem ainda aparecer em texto.</p>
<h2>Resumo</h2>
<p>Ao <strong>terminar</strong> a folha, o helpdesk regista a sua posição (GPS ou, em alternativa, a loja do ticket) e mostra um <strong>mapa só aos agentes</strong> no ticket — <strong>nunca</strong> impede concluir o trabalho.</p>',
  '',
  UTC_TIMESTAMP(), 2, UTC_TIMESTAMP(), 2
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM faq_item WHERE f_number = 'HD-GPS-FOLHA');

UPDATE faq_item SET
  f_name = 'manual-folha-gps',
  f_subject = 'Localização GPS ao terminar a folha de trabalho',
  category_id = 21,
  f_keywords = 'gps localização folha trabalho terminar mapa loja field mode',
  f_field1 = '<p>Registar onde estava ao <strong>terminar uma folha de trabalho</strong>, com mapa interno no ticket (só agentes).</p>',
  f_field2 = '<p>Utilize quando precisa de perceber como funciona o pedido de localização ao carregar em <strong>Terminar trabalho</strong> (computador ou telemóvel).</p>',
  f_field3 = '<h2>Para que serve</h2>
<p>Ao <strong>terminar uma folha de trabalho</strong>, o helpdesk regista <strong>onde estava</strong> nesse momento. Isto ajuda a confirmar intervenções no terreno (loja, cliente, etc.).</p>
<p>A localização <strong>nunca impede</strong> fechar a folha: se o GPS falhar, o sistema usa alternativas ou fecha na mesma, com uma nota interna.</p>
<h2>Quando é pedida</h2>
<p>Só ao carregar em <strong>Terminar trabalho</strong>, depois de preencher resultado, visibilidade no portal, envio de e-mail (se aplicável) e outros campos do resultado (por exemplo agendamento).</p>
<p><strong>Não</strong> é pedida ao iniciar, pausar ou guardar rascunho.</p>
<h2>O que acontece ao carregar «Terminar trabalho»</h2>
<ol>
<li>O botão mostra <strong>«A obter localização…»</strong> e fica temporariamente inactivo.</li>
<li>O <strong>navegador</strong> pode pedir permissão — convém escolher <strong>Permitir</strong>.</li>
<li>O sistema tenta obter o GPS (até cerca de 15 segundos).</li>
<li>De seguida a folha <strong>fecha normalmente</strong>, com ou sem GPS.</li>
</ol>
<h2>Três cenários possíveis</h2>
<table>
<thead><tr><th>Situação</th><th>O que fica registado</th><th>O que vê depois no ticket</th></tr></thead>
<tbody>
<tr><td><strong>GPS OK</strong></td><td>Coordenadas do telemóvel ou computador, com precisão aproximada</td><td>Mapa com a posição real no fecho</td></tr>
<tr><td><strong>GPS indisponível</strong>, mas a loja do ticket tem coordenadas</td><td>Coordenadas <strong>da loja</strong> (alternativa automática)</td><td>Mapa na loja e nota interna a indicar que o GPS falhou</td></tr>
<tr><td><strong>GPS indisponível</strong> e loja sem coordenadas</td><td>Sem mapa; nota interna no registo</td><td>Folha fechada; <strong>sem</strong> secção de mapa</td></tr>
</tbody>
</table>
<h2>Onde ver o mapa</h2>
<ul>
<li>Só na interface de <strong>agente</strong>, no detalhe do ticket, <strong>abaixo da folha de trabalho</strong> fechada.</li>
<li>Aparece a secção <strong>«Mapa da localização»</strong> (Google Maps, vista satélite), com coordenadas e ligação <strong>«Abrir no Google Maps»</strong>.</li>
<li>O <strong>cliente não vê o mapa</strong> no portal nem no e-mail da folha — é informação interna do helpdesk.</li>
</ul>
<h2>Boas práticas no terreno</h2>
<ol>
<li>Permitir localização no browser (Chrome, Safari, etc.) para o site do helpdesk.</li>
<li>No telemóvel, activar GPS/localização do sistema operativo.</li>
<li>Terminar a folha <strong>no local da intervenção</strong>, não horas depois noutro sítio.</li>
<li>Confirmar que o ticket tem a <strong>loja correcta</strong> (menu «Alterar loja» no ticket) — serve de alternativa se o GPS falhar.</li>
<li>Se a loja não tiver coordenadas, peça à administração para as registar (útil em armazéns ou caves onde o GPS falha).</li>
</ol>
<h2>Field Mode (técnico no telemóvel)</h2>
<p>O comportamento é o <strong>mesmo</strong>: ao tocar <strong>Terminar trabalho</strong>, o telemóvel pede localização. Use Safari ou Chrome com permissões activas; em iPhone/iPad confirme que o site do helpdesk pode usar «Localização».</p>
<h2>Perguntas frequentes</h2>
<p><strong>Tenho de aceitar o GPS para fechar a folha?</strong><br>Não. Recusar ou falhar o GPS <strong>não impede</strong> terminar o trabalho.</p>
<p><strong>Demora muito?</strong><br>Normalmente poucos segundos; no máximo cerca de 15 segundos de espera.</p>
<p><strong>Porque aparece a loja e não o sítio onde estou?</strong><br>O GPS falhou ou foi recusado; o sistema usou as coordenadas da loja associada ao ticket.</p>
<p><strong>Porque não vejo mapa nenhum?</strong><br>Não houve GPS <strong>e</strong> a loja não tem coordenadas registadas.</p>
<p><strong>O mapa não carrega?</strong><br>Reporte à administração; as coordenadas podem ainda aparecer em texto.</p>
<h2>Resumo</h2>
<p>Ao <strong>terminar</strong> a folha, o helpdesk regista a sua posição (GPS ou, em alternativa, a loja do ticket) e mostra um <strong>mapa só aos agentes</strong> no ticket — <strong>nunca</strong> impede concluir o trabalho.</p>',
  content_type = 'text/html',
  approved = 1,
  valid_id = 1,
  changed = UTC_TIMESTAMP(),
  changed_by = 2
WHERE f_number = 'HD-GPS-FOLHA';

-- HD-TICKETS-CALENDARIO
INSERT INTO faq_item (
  f_number, f_name, f_subject, f_language_id, state_id, category_id,
  approved, valid_id, content_type, f_keywords,
  f_field1, f_field2, f_field3, f_field6,
  created, created_by, changed, changed_by
)
SELECT
  'HD-TICKETS-CALENDARIO',
  'manual-tickets-calendario',
  'Tickets e calendário — agendamentos',
  3, 2,
  20,
  1, 1, 'text/html',
  'calendário marcação agendamento pendente folha compromisso dashboard cancelado visita retoma',
  '<p>Ligar <strong>tickets</strong> e <strong>marcações no calendário</strong> quando o pedido fica para uma data futura.</p>',
  '<p>Utilize para visitas presenciais, retomas agendadas, formações no cliente ou qualquer continuação com data e hora acordada.</p>',
  '<h2>O que vê na interface</h2>
<table>
<thead><tr><th>O que vê</th><th>Significado</th></tr></thead>
<tbody>
<tr><td><strong>Pendente com Agendamento</strong></td><td>O ticket aguarda uma acção numa data futura.</td></tr>
<tr><td><strong>Agendar no calendário</strong></td><td>Botão na folha de trabalho para criar a marcação.</td></tr>
<tr><td><strong>Marcação registada</strong></td><td>Já existe marcação futura ligada a este ticket.</td></tr>
<tr><td><strong>Agendamentos pendentes</strong></td><td>Lista no painel com o que tem agendado.</td></tr>
<tr><td><strong>[CANCELADO]</strong> no calendário</td><td>A marcação foi anulada (por exemplo, ticket fechado antes da data).</td></tr>
</tbody>
</table>
<p>A <strong>data oficial</strong> é sempre a <strong>marcação no calendário</strong> com o ticket associado — não basta escrever a data numa nota.</p>
<h2>Três formas de agendar</h2>
<h3>1. Pela folha de trabalho (ideal no terreno)</h3>
<p>Quando <strong>termina</strong> uma intervenção mas o ticket <strong>fica para outra altura</strong>:</p>
<ol>
<li>Abra a <strong>folha de trabalho</strong> do ticket.</li>
<li>Em <strong>Resultado</strong>, escolha <strong>«A aguardar intervenção presencial»</strong> ou <strong>«Outro»</strong> e depois <strong>«Pendente com Agendamento»</strong>.</li>
<li>Carregue em <strong>Agendar no calendário</strong> — abre o ecrã habitual de marcação, <strong>com o ticket já associado</strong>.</li>
<li>Indique data, hora, título e o calendário (<strong>BWB</strong> ou <strong>ZS Angola</strong>) e <strong>grave</strong>.</li>
<li>Confirme <strong>«Marcação registada»</strong> (com data e hora).</li>
<li>Só então carregue <strong>Terminar trabalho</strong>.</li>
</ol>
<p><strong>Sem marcação futura, não consegue fechar a folha</strong> nestes resultados.</p>
<h3>2. Pelo calendário</h3>
<ol>
<li>Menu <strong>Calendário</strong>.</li>
<li><strong>Nova marcação</strong> (ou clique na hora desejada).</li>
<li>Associe o <strong>ticket</strong> (número ou pesquisa).</li>
<li>Preencha data, hora e grave.</li>
</ol>
<p>Se o ticket <strong>ainda não estiver fechado</strong>, passa automaticamente a <strong>Pendente com Agendamento</strong>, com a data de retoma igual ao início da marcação.</p>
<h3>3. Pelo ticket</h3>
<ol>
<li>Abra o ticket.</li>
<li>Use <strong>«Novo compromisso»</strong> (ou opção equivalente no menu do ticket).</li>
<li>Crie a marcação como acima.</li>
</ol>
<h2>O que o sistema faz por si</h2>
<table>
<thead><tr><th>Fez isto…</th><th>…acontece isto</th></tr></thead>
<tbody>
<tr><td>Criou marcação <strong>futura</strong> com o ticket</td><td>Ticket → <strong>Pendente com Agendamento</strong>; data de retoma = início da marcação</td></tr>
<tr><td><strong>Alterou</strong> a hora da marcação</td><td>A data de retoma do ticket <strong>actualiza</strong></td></tr>
<tr><td><strong>Apagou</strong> a marcação</td><td>O ticket <strong>mantém o estado</strong>; deixa de aparecer na lista de agendamentos</td></tr>
<tr><td><strong>Fechou</strong> o ticket antes da data</td><td>Marcações futuras ficam <strong>[CANCELADO]</strong> no calendário, com motivo na descrição; saem da lista de pendentes</td></tr>
</tbody>
</table>
<p>Marcações canceladas <strong>continuam visíveis no calendário</strong> (histórico), mas <strong>já não contam</strong> como trabalho por fazer.</p>
<h2>Onde consultar os seus agendamentos</h2>
<p>No <strong>Painel de controlo</strong>, widget <strong>«Agendamentos pendentes»</strong>: data e hora, ticket, cliente, loja e título da marcação. Carregue numa linha para abrir o ticket. Vê apenas tickets a que tem acesso (a sua equipa ou fila).</p>
<h2>Qual calendário usar</h2>
<ul>
<li>Tickets <strong>BWB</strong> → calendário <strong>BWB</strong>.</li>
<li>Tickets <strong>ZS Angola</strong> → calendário <strong>ZS Angola</strong>.</li>
</ul>
<p>Se não vir o calendário certo, peça ajuda à administração (permissões).</p>
<h2>Exemplo — visita presencial</h2>
<ol>
<li>Intervenção no cliente; abre <strong>folha de trabalho</strong>.</li>
<li>Resultado: <strong>«A aguardar intervenção presencial»</strong>.</li>
<li><strong>Agendar no calendário</strong> → próxima visita (ex.: terça, 09:00).</li>
<li><strong>Terminar trabalho</strong>.</li>
<li>No dia marcado, abre o ticket pelo <strong>painel</strong> ou pelo <strong>calendário</strong> e continua.</li>
</ol>
<h2>Exemplo — combinou data por telefone</h2>
<ol>
<li>Acordo com o cliente registado no ticket (e-mail ou nota).</li>
<li>Cria <strong>marcação no calendário</strong> ligada ao ticket.</li>
<li>Ticket fica <strong>Pendente com Agendamento</strong> sem precisar de folha.</li>
<li>No dia, trata o ticket normalmente.</li>
</ol>
<h2>Erros comuns</h2>
<table>
<thead><tr><th>Situação</th><th>O que fazer</th></tr></thead>
<tbody>
<tr><td>«Ainda sem marcação futura» na folha</td><td>Carregue <strong>Agendar no calendário</strong>, grave, e só depois <strong>Terminar trabalho</strong>.</td></tr>
<tr><td>Quis mudar o estado à mão e o sistema não deixou</td><td><strong>Crie a marcação primeiro</strong> (folha, calendário ou Novo compromisso).</td></tr>
<tr><td>Só escreveu a data nas notas</td><td><strong>Insuficiente</strong> — crie marcação no calendário com o ticket ligado.</td></tr>
<tr><td>Apagou a marcação e o ticket ficou «pendente»</td><td><strong>Altere o estado</strong> do ticket se já não fizer sentido.</td></tr>
<tr><td>Fechou o ticket e a marcação ficou [CANCELADO]</td><td><strong>Normal</strong> — não precisa de apagar nada manualmente.</td></tr>
</tbody>
</table>
<h2>O cliente vê isto?</h2>
<p>A marcação interna do calendário <strong>não</strong> aparece automaticamente no portal do cliente. Para informar o cliente, use <strong>e-mail</strong> ou <strong>nota visível no portal</strong>, como habitualmente.</p>
<h2>Perguntas frequentes</h2>
<p><strong>Preciso sempre de folha de trabalho para agendar?</strong><br>Não. Pode agendar só pelo calendário ou pelo ticket. A folha <strong>obriga</strong> marcação apenas nos resultados «intervenção presencial» / «Pendente com Agendamento».</p>
<p><strong>Mudei a hora no calendário. Preciso de alterar o ticket?</strong><br>Não. A data de retoma <strong>acompanha</strong> a marcação.</p>
<p><strong>O responsável vê agendamentos da equipa?</strong><br>Sim, no painel, dentro dos tickets a que tem acesso (como nas folhas abertas).</p>
<h2>Resumo</h2>
<p>Marque no <strong>calendário</strong> com o <strong>ticket associado</strong>. O ticket fica <strong>Pendente com Agendamento</strong>, aparece em <strong>Agendamentos pendentes</strong>, e se <strong>fechar o ticket</strong> antes da data a marcação fica <strong>cancelada</strong> no calendário com o motivo registado.</p>',
  '',
  UTC_TIMESTAMP(), 2, UTC_TIMESTAMP(), 2
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM faq_item WHERE f_number = 'HD-TICKETS-CALENDARIO');

UPDATE faq_item SET
  f_name = 'manual-tickets-calendario',
  f_subject = 'Tickets e calendário — agendamentos',
  category_id = 20,
  f_keywords = 'calendário marcação agendamento pendente folha compromisso dashboard cancelado visita retoma',
  f_field1 = '<p>Ligar <strong>tickets</strong> e <strong>marcações no calendário</strong> quando o pedido fica para uma data futura.</p>',
  f_field2 = '<p>Utilize para visitas presenciais, retomas agendadas, formações no cliente ou qualquer continuação com data e hora acordada.</p>',
  f_field3 = '<h2>O que vê na interface</h2>
<table>
<thead><tr><th>O que vê</th><th>Significado</th></tr></thead>
<tbody>
<tr><td><strong>Pendente com Agendamento</strong></td><td>O ticket aguarda uma acção numa data futura.</td></tr>
<tr><td><strong>Agendar no calendário</strong></td><td>Botão na folha de trabalho para criar a marcação.</td></tr>
<tr><td><strong>Marcação registada</strong></td><td>Já existe marcação futura ligada a este ticket.</td></tr>
<tr><td><strong>Agendamentos pendentes</strong></td><td>Lista no painel com o que tem agendado.</td></tr>
<tr><td><strong>[CANCELADO]</strong> no calendário</td><td>A marcação foi anulada (por exemplo, ticket fechado antes da data).</td></tr>
</tbody>
</table>
<p>A <strong>data oficial</strong> é sempre a <strong>marcação no calendário</strong> com o ticket associado — não basta escrever a data numa nota.</p>
<h2>Três formas de agendar</h2>
<h3>1. Pela folha de trabalho (ideal no terreno)</h3>
<p>Quando <strong>termina</strong> uma intervenção mas o ticket <strong>fica para outra altura</strong>:</p>
<ol>
<li>Abra a <strong>folha de trabalho</strong> do ticket.</li>
<li>Em <strong>Resultado</strong>, escolha <strong>«A aguardar intervenção presencial»</strong> ou <strong>«Outro»</strong> e depois <strong>«Pendente com Agendamento»</strong>.</li>
<li>Carregue em <strong>Agendar no calendário</strong> — abre o ecrã habitual de marcação, <strong>com o ticket já associado</strong>.</li>
<li>Indique data, hora, título e o calendário (<strong>BWB</strong> ou <strong>ZS Angola</strong>) e <strong>grave</strong>.</li>
<li>Confirme <strong>«Marcação registada»</strong> (com data e hora).</li>
<li>Só então carregue <strong>Terminar trabalho</strong>.</li>
</ol>
<p><strong>Sem marcação futura, não consegue fechar a folha</strong> nestes resultados.</p>
<h3>2. Pelo calendário</h3>
<ol>
<li>Menu <strong>Calendário</strong>.</li>
<li><strong>Nova marcação</strong> (ou clique na hora desejada).</li>
<li>Associe o <strong>ticket</strong> (número ou pesquisa).</li>
<li>Preencha data, hora e grave.</li>
</ol>
<p>Se o ticket <strong>ainda não estiver fechado</strong>, passa automaticamente a <strong>Pendente com Agendamento</strong>, com a data de retoma igual ao início da marcação.</p>
<h3>3. Pelo ticket</h3>
<ol>
<li>Abra o ticket.</li>
<li>Use <strong>«Novo compromisso»</strong> (ou opção equivalente no menu do ticket).</li>
<li>Crie a marcação como acima.</li>
</ol>
<h2>O que o sistema faz por si</h2>
<table>
<thead><tr><th>Fez isto…</th><th>…acontece isto</th></tr></thead>
<tbody>
<tr><td>Criou marcação <strong>futura</strong> com o ticket</td><td>Ticket → <strong>Pendente com Agendamento</strong>; data de retoma = início da marcação</td></tr>
<tr><td><strong>Alterou</strong> a hora da marcação</td><td>A data de retoma do ticket <strong>actualiza</strong></td></tr>
<tr><td><strong>Apagou</strong> a marcação</td><td>O ticket <strong>mantém o estado</strong>; deixa de aparecer na lista de agendamentos</td></tr>
<tr><td><strong>Fechou</strong> o ticket antes da data</td><td>Marcações futuras ficam <strong>[CANCELADO]</strong> no calendário, com motivo na descrição; saem da lista de pendentes</td></tr>
</tbody>
</table>
<p>Marcações canceladas <strong>continuam visíveis no calendário</strong> (histórico), mas <strong>já não contam</strong> como trabalho por fazer.</p>
<h2>Onde consultar os seus agendamentos</h2>
<p>No <strong>Painel de controlo</strong>, widget <strong>«Agendamentos pendentes»</strong>: data e hora, ticket, cliente, loja e título da marcação. Carregue numa linha para abrir o ticket. Vê apenas tickets a que tem acesso (a sua equipa ou fila).</p>
<h2>Qual calendário usar</h2>
<ul>
<li>Tickets <strong>BWB</strong> → calendário <strong>BWB</strong>.</li>
<li>Tickets <strong>ZS Angola</strong> → calendário <strong>ZS Angola</strong>.</li>
</ul>
<p>Se não vir o calendário certo, peça ajuda à administração (permissões).</p>
<h2>Exemplo — visita presencial</h2>
<ol>
<li>Intervenção no cliente; abre <strong>folha de trabalho</strong>.</li>
<li>Resultado: <strong>«A aguardar intervenção presencial»</strong>.</li>
<li><strong>Agendar no calendário</strong> → próxima visita (ex.: terça, 09:00).</li>
<li><strong>Terminar trabalho</strong>.</li>
<li>No dia marcado, abre o ticket pelo <strong>painel</strong> ou pelo <strong>calendário</strong> e continua.</li>
</ol>
<h2>Exemplo — combinou data por telefone</h2>
<ol>
<li>Acordo com o cliente registado no ticket (e-mail ou nota).</li>
<li>Cria <strong>marcação no calendário</strong> ligada ao ticket.</li>
<li>Ticket fica <strong>Pendente com Agendamento</strong> sem precisar de folha.</li>
<li>No dia, trata o ticket normalmente.</li>
</ol>
<h2>Erros comuns</h2>
<table>
<thead><tr><th>Situação</th><th>O que fazer</th></tr></thead>
<tbody>
<tr><td>«Ainda sem marcação futura» na folha</td><td>Carregue <strong>Agendar no calendário</strong>, grave, e só depois <strong>Terminar trabalho</strong>.</td></tr>
<tr><td>Quis mudar o estado à mão e o sistema não deixou</td><td><strong>Crie a marcação primeiro</strong> (folha, calendário ou Novo compromisso).</td></tr>
<tr><td>Só escreveu a data nas notas</td><td><strong>Insuficiente</strong> — crie marcação no calendário com o ticket ligado.</td></tr>
<tr><td>Apagou a marcação e o ticket ficou «pendente»</td><td><strong>Altere o estado</strong> do ticket se já não fizer sentido.</td></tr>
<tr><td>Fechou o ticket e a marcação ficou [CANCELADO]</td><td><strong>Normal</strong> — não precisa de apagar nada manualmente.</td></tr>
</tbody>
</table>
<h2>O cliente vê isto?</h2>
<p>A marcação interna do calendário <strong>não</strong> aparece automaticamente no portal do cliente. Para informar o cliente, use <strong>e-mail</strong> ou <strong>nota visível no portal</strong>, como habitualmente.</p>
<h2>Perguntas frequentes</h2>
<p><strong>Preciso sempre de folha de trabalho para agendar?</strong><br>Não. Pode agendar só pelo calendário ou pelo ticket. A folha <strong>obriga</strong> marcação apenas nos resultados «intervenção presencial» / «Pendente com Agendamento».</p>
<p><strong>Mudei a hora no calendário. Preciso de alterar o ticket?</strong><br>Não. A data de retoma <strong>acompanha</strong> a marcação.</p>
<p><strong>O responsável vê agendamentos da equipa?</strong><br>Sim, no painel, dentro dos tickets a que tem acesso (como nas folhas abertas).</p>
<h2>Resumo</h2>
<p>Marque no <strong>calendário</strong> com o <strong>ticket associado</strong>. O ticket fica <strong>Pendente com Agendamento</strong>, aparece em <strong>Agendamentos pendentes</strong>, e se <strong>fechar o ticket</strong> antes da data a marcação fica <strong>cancelada</strong> no calendário com o motivo registado.</p>',
  content_type = 'text/html',
  approved = 1,
  valid_id = 1,
  changed = UTC_TIMESTAMP(),
  changed_by = 2
WHERE f_number = 'HD-TICKETS-CALENDARIO';
