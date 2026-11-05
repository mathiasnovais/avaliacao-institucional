/* ============================================================
   RELEASES — a lista única de atualizações do portal.

   >>> ESTE É O ÚNICO LUGAR ONDE UMA ATUALIZAÇÃO É ESCRITA. <<<
   Quem consome:
     · o MURAL (pop-up da tela inicial) — mostra a release mais nova que a
       pessoa ainda não viu, com ilustração e passo a passo;
     · a tela ATUALIZAÇÕES (atualizacoes.html) — mostra o histórico inteiro.
   Ter a lista em dois lugares seria a receita para o mural dizer uma coisa e
   a tela de histórico dizer outra. Por isso ela mora aqui, sozinha.

   COMO ANUNCIAR UMA ATUALIZAÇÃO NOVA
     1. acrescente um objeto no TOPO de RELEASES (mais nova primeiro);
     2. `v` é a identidade da release — é por ele que o portal sabe quem já
        viu o quê, e ele NUNCA muda depois de publicado;
     3. se a release tiver aviso no sino, o `marco` do n8n_notificacoes.sql
        tem de ser exatamente igual a este `v`.

   A data é a da RELEASE (o dia em que aquilo foi ao ar), não a do dia em que
   cada coisa foi feita — uma release junta trabalho de vários dias.

   Campos de cada item:
     ic   emoji do item        img  chave da ilustração (desenhada no mural)
     t    título               d    o que mudou e por quê (aceita <b>)
     p    passo a passo, na ordem em que a pessoa faz
   ============================================================ */
window.PORTAL_RELEASES = [

  { v:'2026-10-07', data:'07/10/2026', titulo:'Bem-vindos de volta: o 3º trimestre começou',
    /* janela = faixa de datas em destaque no cabeçalho do mural (só esta release tem) */
    janela:{ rotulo:'3º Trimestre · 2026', inicio:'07/10/2026', fim:'23/11/2026' },
    resumo:'A rodada do 3º trimestre abre (07/10 a 23/11) com a casa renovada: dashboards unificados, '
    + 'andamento da rede na tela inicial, Gestão de Pessoas, termo de devolutiva em PDF e uma leva de melhorias.',
    itens:[
      { ic:'🎒', img:'tri3',
        t:'Bem-vindos à avaliação do 3º trimestre',
        d:'A nova rodada está aberta: a janela vai de <b>07/10</b> a <b>23/11/2026</b>. Todo mundo volta a aparecer '
        + 'como <b>pendente</b> — é a rodada recomeçando, não um apagão: tudo o que foi feito no 2º trimestre '
        + 'continua guardado e segue valendo como histórico de evolução.',
        p:['Abra a tela de avaliação da sua equipe pelo menu lateral — a mesma de sempre.',
           'Sua lista volta inteira como <b>Pendente</b>: é o recomeço da rodada, não um erro.',
           'Preencha como de costume. O <b>Salvar rascunho</b> continua valendo entre uma sessão e outra.',
           'Agende a devolutiva, prepare o texto com calma e conclua no dia marcado.',
           'O prazo para concluir tudo é <b>23/11/2026</b> — o contador nas telas acompanha os dias.'] },

      { ic:'📊', img:'dash',
        t:'Dashboards: tela única e o quadro de respostas',
        d:'Os dashboards individuais dos quatro cargos viraram <b>uma tela só</b>, com a mesma régua para todo mundo. '
        + 'O detalhe por critério aparece no quadro <b>Respostas dos avaliadores</b>, e a evolução entre trimestres '
        + 'é calculada automaticamente. Quem enxerga a rede conta ainda com o <b>comparativo por cargo</b>, '
        + 'que posiciona cada pessoa entre os pares.',
        p:['No Dashboard Geral, clique numa pessoa para abrir o dashboard individual dela.',
           'Role até <b>Respostas dos avaliadores</b> para ver o detalhe por critério.',
           'Conforme o 3º trimestre for preenchido, a seção de evolução compara com o 2º automaticamente.'] },

      { ic:'📈', img:'painel',
        t:'Tela inicial: andamento da rede',
        d:'A primeira tela ganhou um painel com o andamento da avaliação em toda a rede — a equipe Central e '
        + 'cada unidade, lado a lado. Dá para ver onde a rodada avança e onde precisa de um empurrão, '
        + 'sem abrir unidade por unidade.',
        p:['Entre no portal: o painel está na própria tela inicial.',
           'Cada linha é uma unidade; a barra mostra o quanto da rodada atual já foi feito.',
           'Com a virada para o 3º trimestre ele recomeça do zero — e vai subindo conforme as avaliações acontecem.'] },

      { ic:'👥', img:'pessoas',
        t:'Gestão de Pessoas: o organograma da rede',
        d:'Uma tela nova com quem é quem: a equipe Central e, unidade por unidade, direção, supervisões e '
        + 'coordenações — com foto, e-mail e segmento. Todos podem consultar.',
        p:['Abra <b>Gestão de Pessoas</b> no menu lateral.',
           'Navegue pelos cards da Central e de cada unidade.',
           'Achou algo errado — pessoa que saiu, cargo desatualizado? Abra um chamado pelo <b>Suporte</b>: é o caminho mais rápido.'] },

      { ic:'📄', img:'termo',
        t:'Termo de devolutiva em PDF',
        d:'A devolutiva concluída agora vira documento: o <b>Termo de Devolutiva</b> sai em PDF com o logo da rede — '
        + 'devolutiva, plano de ação e o termo de ciência com espaço para assinatura — pronto para imprimir ou arquivar.',
        p:['Abra a avaliação da pessoa com a devolutiva preenchida.',
           'Gere o <b>Termo de devolutiva</b> pela opção de documento da tela.',
           'Baixe o PDF para arquivar, ou imprima para colher a assinatura no papel.'] },

      { ic:'✨', img:'extras',
        t:'E mais: fotos, rascunho protegido e férias',
        d:'Três melhorias menores que mudam o dia a dia: as pessoas aparecem com <b>foto</b> nas listas e dashboards; '
        + 'o formulário <b>salva o rascunho sozinho</b> pouco antes de a sessão expirar, para nada se perder; e o '
        + '<b>Controle de Férias</b> organiza os períodos da equipe, com exportação em planilha.',
        p:['As fotos aparecem automaticamente — não precisa fazer nada.',
           'Deixou o formulário aberto e a sessão venceu? Pouco antes disso ele salvou o rascunho por você.',
           'Gestores encontram o <b>Controle de Férias</b> no menu lateral.'] }
    ] },

  { v:'2026-09-30', data:'30/09/2026', titulo:'Suporte com assunto livre',
    resumo:'O Suporte deixou de ser só duas opções prontas: agora dá para escrever o que você quiser.',
    itens:[
      { ic:'💬', img:'outro',
        t:'Suporte: agora dá para escrever o que você quiser',
        d:'O Suporte começou com duas opções prontas, sobre a lista de pessoas. Só que nem todo problema cabe numa '
        + 'lista pronta — e o que não cabia acabava virando mensagem solta, fora da fila. Existe agora a opção '
        + '<b>Outro assunto</b>, com uma caixa de texto livre: um erro na tela, uma dúvida, um pedido, o que for.',
        p:['Abra o <b>Suporte</b>: no menu lateral ou no botão redondo no canto inferior direito.',
           'Escolha <b>Outro assunto</b>, a segunda opção da tela.',
           'Escreva com as suas palavras. Se for um erro, conte <b>em que tela</b> você estava e <b>o que estava fazendo</b> — é o que mais ajuda a achar o problema.',
           'Clique em <b>Enviar chamado</b>. Ele entra na mesma fila dos outros.',
           'A resposta chega pelo sino, no topo da tela inicial.'] }
    ] },

  { v:'2026-09-29', data:'29/09/2026', titulo:'Suporte, avisos, devolutiva e painel',
    resumo:'A leva que abriu o canal de suporte dentro do portal, criou os avisos no sino, soltou o preenchimento '
    + 'da devolutiva e juntou os filtros do Dashboard Geral.',
    itens:[
      { ic:'🛟', img:'suporte',
        t:'Suporte: avise um problema sem sair do portal',
        d:'Antes, um erro na sua lista de pessoas só chegava até nós por mensagem ou conversa de corredor — '
        + 'e muita coisa se perdia no caminho. Agora existe um canal dentro da própria plataforma, e o chamado '
        + 'já chega com o contexto: quem abriu, de qual tela e quais pessoas estão erradas.',
        p:['Clique em <b>Suporte</b> no menu lateral, ou no botão redondo no canto inferior direito — ele existe em todas as telas.',
           'Escolha <b>Lista de pessoas errada</b>.',
           'Diga qual é o caso: <b>“Estou vendo alguém que não deveria”</b> ou <b>“Não vejo alguém que deveria”</b>.',
           'Vendo alguém a mais: sua lista aparece com foto e nome — marque quem não é da sua equipe.',
           'Faltando alguém: informe o nome e o cargo. Se for docente, o formulário pede o ano e a matéria.',
           'Envie. Você acompanha a resposta pelo sino, no topo da tela inicial.'] },

      { ic:'🔔', img:'avisos',
        t:'Avisos: o sino no topo da tela inicial',
        d:'O portal passou a ter um lugar único para falar com você. Hoje ele avisa sobre os seus chamados; '
        + 'daqui para frente também servirá para comunicados — prazos, mudanças e o que mais precisar chegar a todos.',
        p:['O sino fica no topo da tela inicial, ao lado do seu cargo.',
           'A bolinha vermelha mostra quantos avisos você ainda não leu.',
           'Clique para abrir. Cada aviso diz o que aconteceu e quando.',
           'Clicar em um aviso marca como lido e leva à tela onde aquilo aconteceu.',
           'Se preferir limpar tudo de uma vez, use <b>Marcar todas como lidas</b>.'] },

      { ic:'📝', img:'devolutiva',
        t:'Devolutiva: escreva antes, conclua no dia',
        d:'Esta é a mudança que mais muda o dia a dia. Antes, a tela da devolutiva só abria na data agendada — '
        + 'quem quisesse preparar o texto com calma não tinha como. Agora o preenchimento é livre desde já; '
        + 'o que continua preso à data é a conclusão, porque ela marca que a conversa aconteceu.',
        p:['No card da pessoa, clique em <b>Preencher</b> — ele aparece mesmo antes da data marcada.',
           'Escreva o que quiser: devolutiva, plano de ação, pontos fortes e de desenvolvimento.',
           'Use <b>Salvar rascunho</b> quantas vezes precisar. Nada se perde entre uma sessão e outra.',
           'Antes do dia, o botão <b>Concluir devolutiva</b> não aparece — e um aviso na tela explica o porquê.',
           'No dia agendado, entre de novo, revise e clique em <b>Concluir devolutiva</b>.'] },

      { ic:'📊', img:'dash',
        t:'Dashboard Geral: um filtro só, e a tela inteira acompanha',
        d:'Eram dois controles no topo que faziam coisas parecidas, e não era óbvio que um dependia do outro. '
        + 'Viraram um. E, ao escolher uma pessoa, o painel inteiro passa a mostrar o recorte dela — '
        + 'cabeçalho, números e agenda de devolutivas, tudo junto.',
        p:['Abra <b>Visualização</b>, no topo do painel.',
           'Use a <b>busca</b> para achar alguém pelo nome, ou os <b>atalhos de cargo</b> logo abaixo.',
           'Escolher um cargo deixa na lista só as pessoas daquele cargo — o número ao lado diz quantas são.',
           'Clique na pessoa: o painel inteiro passa a mostrar a equipe dela.',
           'Para voltar ao seu recorte, escolha <b>Minha equipe — quem eu avalio</b>.'] },

      { ic:'🧭', img:'coord',
        t:'Avaliação da Coordenação de Área',
        d:'A Coordenação de Área passou a ter instrumento próprio, no mesmo formato das demais avaliações da rede. '
        + 'Quem avalia os coordenadores encontra a tela no menu, junto das outras.',
        p:['Abra <b>Avaliações → Coordenação de Área</b> no menu lateral.',
           'Escolha o coordenador na lista.',
           'Preencha os critérios e a síntese, como nas outras avaliações.',
           'Agende a devolutiva e siga o mesmo passo a passo: preencher agora, concluir no dia.'] }
    ] }

];
