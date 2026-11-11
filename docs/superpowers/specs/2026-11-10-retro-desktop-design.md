# Retro98 — ambiente retrô estilo Windows 98 para macOS — Design

Data: 2026-11-10
Status: rascunho para aprovação

Legenda: **[decidido]** = decisão do autor do projeto · **[minha escolha]** = default escolhido durante o design, pode ser revisto.

---

## 1. Intenção

Dar a qualquer pessoa com um Mac a possibilidade de **viver num ambiente com visual e jeito do Windows 98 na maior parte do tempo, sem quebrar nada do que ela precisa para trabalhar**. **[decidido]**

O macOS não permite trocar o visual do sistema (janelas, menus e Finder ficam num volume selado). Por isso o projeto não é um "tema". É um **conjunto de apps próprios, desenhados no estilo 98, que rodam por cima do macOS e convivem com ele**. Isso inclui área de trabalho, barra de tarefas, gerenciador de arquivos, prompt e assim por diante, mais ajustes reversíveis do sistema e temas para apps de terceiros que aceitam temas.

## 2. Público e distribuição

- Projeto **open source, público no GitHub**. Quem quiser deve conseguir instalar só seguindo o README. **[decidido]**
- A instalação compila na máquina da pessoa: clona o repositório e roda um script. Sem conta paga de desenvolvedor Apple e sem alerta de "app não confiável", porque o build é local. **[minha escolha]**
- Licença MIT para o código. Fontes ou recursos de terceiros mantêm a licença deles. **[minha escolha]**
- Interface em português (pt-BR) e inglês, seguindo o idioma do sistema. README em inglês, com versão em pt-BR. **[minha escolha]**
- macOS mínimo: 14 (Sonoma). Desenvolvido e testado no macOS 27, Apple Silicon. **[minha escolha]**

## 3. Objetivos, não-objetivos e anti-objetivos

### Objetivos
- Moldura 98 completa em volta do uso diário: área de trabalho, barra de tarefas e menu Iniciar.
- Gerenciador de arquivos estilo Explorer que funcione de verdade no trabalho do dia a dia.
- Apps retrô para o que dá para refazer bem: Prompt, Painel de Controle, Bloco de Notas e, por último, um navegador.
- Temas 98 para apps de terceiros que aceitam temas: Chrome, Sublime Text e Terminal.app.
- Cada peça pode ser ligada e desligada sozinha. Uma ação única volta tudo ao macOS normal.

### Não-objetivos
- Refazer apps de terceiros como Chrome, WhatsApp, Office ou VS Code. No máximo, aplicar tema onde o app permite.
- Fazer um fork do Chromium. Foi avaliado e descartado: ~100 GB, horas de build, perda de sync e DRM, e risco de segurança por atraso de atualização. **[decidido: usar navegador próprio com WebKit]**
- Recriar jogos do Windows.
- Mudar janelas, menus ou diálogos nativos do macOS (impossível sem desligar proteções do sistema).

### Anti-objetivos (é falha mesmo se "funcionar")
- **Quebrar o fluxo de trabalho**: perder arquivos, travar o Mac, impedir acesso a algo que o macOS normal permite.
- Exigir desligar o SIP ou qualquer proteção do sistema, ou modificar arquivos do macOS.
- Deixar o Mac num estado que a pessoa não sabe desfazer.
- Usar material da Microsoft (ícones, sons, logotipo, papéis de parede, fontes, nomes de produto como "Windows Explorer" ou "Internet Explorer"). O repositório é público, então **tudo tem que ser original "no estilo"**. "Inspirado no Windows 98" pode aparecer no README.
- Visual borrado ou "meio moderno": se é retrô, os pixels têm que ser nítidos.

## 4. Restrições técnicas e de convivência

- **Os originais continuam existindo.** Finder, Terminal, Dock e a barra de menus do macOS seguem rodando. Os apps retrô mexem nos mesmos arquivos e não criam formatos próprios.
- **Os atalhos do Mac continuam valendo** nos apps retrô (⌘C, ⌘V, ⌘W, ⌘Q etc.). Cada app retrô mantém o menu do app na barra de menus do macOS, com pelo menos Sobre, Ajustes e Sair, além do menu desenhado dentro da janela no estilo 98.
- **A barra de menus do macOS fica visível por padrão** (status de Wi-Fi, bateria, Central de Controle). Escondê-la é opção no Painel de Controle. **[minha escolha]**
- **Os apps retrô se comportam como apps de Mac**: aparecem no ⌘Tab, no Mission Control e em Spaces.
- Permissões: a barra de tarefas precisa de **Acessibilidade** para listar, ativar e minimizar janelas de outros apps. O instalador abre o painel certo e o README explica. **O instalador também pede Acesso Total ao Disco para o Explorer e o Shell** (como ForkLift e Path Finder), o que libera a Lixeira completa (ícone cheio/vazio, listar, esvaziar) e todas as pastas sem avisos repetidos. **[decidido]** **Quem recusar continua usando tudo**: a Lixeira passa a abrir no Finder, o ícone fica sempre igual e o macOS pode perguntar pasta por pasta. Desligar, reiniciar e fazer logout usam Automação (um aviso do macOS na primeira vez). **[minha escolha]**
- **Assinatura local estável é obrigatória.** O instalador cria um certificado de assinatura local na primeira instalação e assina todos os apps com ele. Builds ad-hoc fazem o macOS esquecer **todas** as permissões concedidas a cada atualização (Acessibilidade, pastas, automação). **[minha escolha]**
- **APIs do macOS:** usar APIs públicas. A única API privada permitida é `_AXUIElementGetWindow` (associa janela de Acessibilidade ao ID de janela; estável há anos e usada por AltTab, Rectangle e Hammerspoon), isolada num único ponto e com alternativa se deixar de existir. Nada de SkyLight/CGS/CoreDock. **[minha escolha]**
- **Nomes:** os apps usam nomes genéricos (Explorer, Bloco de Notas/Notepad, Meu Computador/My Computer, Lixeira/Recycle Bin, Painel de Controle/Control Panel, Iniciar/Start), como o ReactOS faz há anos em projeto público. Nunca "Windows" nem "Microsoft" em nomes ou identificadores. **[minha escolha]**

## 5. Linguagem visual compartilhada

Todos os apps usam a mesma base visual, para ficarem consistentes:

- **Paleta clássica:** face `#C0C0C0`, sombra `#808080`, luz `#FFFFFF`, sombra escura `#000000`, título ativo em degradê `#000080` → `#1084D0`, título inativo em degradê `#808080` → `#C0C0C0`, seleção `#000080` com texto branco, área de trabalho `#008080`.
- **Relevos:** bordas de 2 px com o padrão clássico (elevado: luz em cima e à esquerda, sombras embaixo e à direita; afundado: o inverso), usadas em botões, campos, painéis e janelas.
- **Escala de pixels:** 1 pt = 1 "pixel" retrô. Em tela Retina, cada pixel retrô vira 2×2, nítido, sem suavização.
- **Texto:** Tahoma 13 px (negrito: 12 px) **sem anti-aliasing**, com a aparência de fonte bitmap. **[decidido em 2026-11-11, depois do teste da 2B: era 11 px, ficou pequeno demais]** A Tahoma já vem instalada no macOS (`/System/Library/Fonts/Supplemental/Tahoma.ttf`) e **não é redistribuída**. Negrito para títulos de janela e itens padrão. A técnica de renderização fica com o construtor, desde que o resultado seja pixel nítido.
- **Fonte monoespaçada** (Prompt): uma fonte de PC clássico com licença livre. Sugestão: a família "Px437 IBM VGA" do *Ultimate Oldschool PC Font Pack* (CC BY-SA 4.0), redistribuível com atribuição. O construtor confirma a licença antes de incluir.
- **Componentes da base:** janela com barra de título e botões `_ □ ×` (arrastar, redimensionar pelas bordas e pela alça do canto, duplo clique maximiza), barra de menus dentro da janela com menus suspensos, botões, caixas de seleção, botões de opção, campos de texto, listas, árvore, abas, barras de rolagem clássicas (setas e trilho pontilhado), barra de status, barra de progresso em blocos, caixas de mensagem (informação, aviso, erro, pergunta), diálogos de abrir e salvar próprios, menus de contexto e dicas de ferramenta (tooltip).
- **Ícones:** pixel art **original**, 32×32 e 16×16, para pastas, tipos de arquivo, discos, Meu Computador, Lixeira (vazia e cheia), Painel de Controle e cada app retrô. **Ícones de apps de Mac** (Chrome, WhatsApp etc.) usam o ícone real do app reduzido para 32×32 e 16×16 e ampliado **sem suavização**, ganhando aspecto pixelado sem perder o reconhecimento. **[minha escolha]**
- **Botão Iniciar:** logotipo original, sem a bandeira da Microsoft.
- **Sons:** sons retrô **originais** (sintetizados pelo projeto) para início do Shell, erro, aviso e esvaziar a Lixeira. Podem ser desligados.

## 6. Peças, em ordem de entrega

Cada fase pode ser usada sozinha, tem como desfazer e é testada pelo autor no próprio Mac antes de passar para a próxima. **[decidido: entrega por partes]**

### Fase 1 — Ajustes base do sistema
Script que aplica ajustes nativos e reversíveis do macOS. **Antes de cada mudança, guarda o valor original (ou o fato de que não existia)**. A restauração devolve exatamente o estado anterior.

- Papel de parede sólido `#008080` (PNG gerado na resolução da tela).
- Modo claro. Cor de destaque grafite, cor de seleção azul-marinho `#000080`. **[minha escolha]**
- Reduzir transparência e aumentar contraste (bordas marcadas). Se o macOS negar a escrita dessas preferências, o script abre o painel de Acessibilidade e explica o que marcar.
- Ponteiro com preenchimento branco e contorno preto.
- Barras de rolagem sempre visíveis. Animações de janela desligadas. Duplo clique na barra de título maximiza.
- Finder no jeito do Explorer: barra de status, barra de caminho, extensões sempre visíveis, pastas primeiro, visualização em lista, novas janelas abrindo na pasta pessoal.
- Pronto quando: aplicar e restaurar em sequência deixa todas as preferências tocadas idênticas ao início.

### Fase 2 — Base visual e Shell
A base visual da seção 5, mais o Shell, que tem três partes:

**Área de trabalho**
- Fundo `#008080` (ou o papel de parede escolhido no Painel de Controle), em todas as telas.
- Ícones fixos: Meu Computador, Meus Documentos (`~/Documents`), Lixeira.
- Os arquivos de `~/Desktop` aparecem como ícones: a área de trabalho é a pasta real.
- Duplo clique abre. Clique direito abre menu de contexto. Arrastar reorganiza ícones, move arquivos e troca arquivos com outros apps. Há seleção por retângulo.
- A área de trabalho do Finder fica escondida enquanto o Shell estiver ativo.

**Barra de tarefas**
- Embaixo, largura total, ~28 pt, por cima de tudo, só na tela principal. **[minha escolha]**
- **Um botão por janela aberta no Space atual** (como nas áreas de trabalho virtuais do Windows), com ícone e título. **[minha escolha]** Clique ativa a janela; clique na janela já ativa minimiza. O menu de contexto tem Restaurar, Minimizar e Fechar.
- Área de notificação: relógio (data na dica), bateria e volume. Clicar abre o controle correspondente do macOS.
- **Janelas maximizadas não podem ficar por baixo da barra de tarefas.** Abordagem sugerida: manter o Dock ativo, no menor tamanho e embaixo da barra, para que o macOS reserve o espaço; a barra fica num nível acima do Dock e o cobre. O construtor valida e, se não funcionar, propõe alternativa.
- Some quando um app está em tela cheia.

**Menu Iniciar**
- Faixa lateral vertical com o nome do projeto e logotipo original.
- Itens: Programas (submenus espelhando `/Applications`, `/System/Applications` e `~/Applications`, com pastas virando submenus), Documentos (recentes), Configurações (Painel de Controle e Ajustes do Sistema), Localizar (busca usando o Spotlight), Ajuda (abre o README), Executar… (abre app, caminho, URL ou comando) e Desligar… (Desligar, Reiniciar, Fazer logout, Repouso, sempre com confirmação).
- Atalho de teclado para abrir: ⌃⎋. **[minha escolha]**

**Recuperação**
- O Shell roda como LaunchAgent e reinicia sozinho se cair.
- **Se cair repetidamente** (por exemplo, 3 vezes em 1 minuto), ele desiste, devolve a área de trabalho do Finder e o Dock no tamanho normal, e avisa a pessoa.
- Desligar o Shell, pelo Painel de Controle ou pelo desinstalador, também devolve os dois.

### Fase 3 — Explorer (gerenciador de arquivos)
**Janela**
- Menus: Arquivo, Editar, Exibir, Ir, Favoritos e Ajuda.
- Barra de ferramentas: Voltar, Avançar, Acima, Recortar, Copiar, Colar, Desfazer, Excluir, Propriedades e Modos de exibição.
- Barra de endereço editável. Árvore à esquerda (Área de trabalho › Meu Computador › volumes › pastas, mais atalhos como Downloads).
- Painel direito com Ícones grandes, Ícones pequenos, Lista e Detalhes (colunas Nome, Tamanho, Tipo e Modificado, ordenáveis).
- Barra de status com número de objetos, tamanho e espaço livre.

**Meu Computador**
- Mostra disco interno, discos externos e volumes de rede, com espaço livre, além do atalho para o Painel de Controle.

**Operações obrigatórias** (o que precisa funcionar sem falha para não voltar ao Finder) **[minha escolha]**
- Abrir arquivo com o app padrão e "Abrir com…".
- Copiar, recortar e colar, **interoperando com o Finder**: copiar no Explorer e colar no Finder funciona, e o contrário também.
- Arrastar e soltar entre janelas e com outros apps.
- Renomear com F2 ou Enter. Nova pasta.
- Excluir manda para a Lixeira do macOS, com confirmação. Esvaziar Lixeira, com confirmação.
- "Restaurar" da Lixeira funciona para itens excluídos pelos apps retrô, que guardam o local original. Itens excluídos por outros apps são restaurados pelo Finder, com um atalho "Abrir no Finder". O macOS não tem API pública para o "Devolver" do Finder. **[minha escolha]**
- Conflito ao copiar: "Substituir arquivo?" com Sim, Sim para todos, Não e Cancelar.
- Diálogo de progresso para cópias longas, com animação original e Cancelar.
- Propriedades: tamanho (com cálculo de pastas), datas, local e tipo.
- Quick Look com a barra de espaço. Mostrar ou ocultar arquivos ocultos. Filtrar por nome na pasta atual.

**Explorer como padrão**
- Opção no Painel de Controle, **desligada por padrão**: faz o "Mostrar no Finder" de outros apps abrir o Explorer (via preferência `NSFileViewer`).

**Fora de escopo**
- iCloud (status de sincronização), etiquetas, AirDrop, compartilhamento e gravação de disco. O Finder continua disponível para isso.

### Fase 4 — Prompt
- Emulador de terminal completo dentro de uma janela 98, rodando o shell da pessoa (`$SHELL`, como login).
- Sugestão de biblioteca: **SwiftTerm** (MIT). O construtor confirma.
- Fundo preto, texto cinza-claro e fonte monoespaçada de PC clássico.
- Deve ter: copiar e colar, redimensionar, histórico de rolagem, cores ANSI, Unicode e acentos.
- Várias janelas em vez de abas.
- Não substitui o Terminal como padrão do sistema.

### Fase 5 — Painel de Controle
- Janela de ícones no estilo 98.
- **Vídeo**: papel de parede e cor da área de trabalho.
- **Aparência**: os ajustes da Fase 1, um a um.
- **Mouse**: ponteiro.
- **Sons**: ligar e desligar sons retrô; usar o som retrô como alerta do macOS.
- **Componentes**: liga e desliga cada peça (Shell, Explorer como padrão, barra de menus escondida etc.).
- **Atalhos para painéis do macOS**: Rede, Impressoras, Teclado, Data/Hora e outros abrem o painel correspondente nos Ajustes do Sistema.
- **Botão "Voltar ao macOS normal"**: desliga todas as peças e restaura tudo o que foi guardado.

### Fase 6 — Bloco de Notas (e talvez visualizador de imagens)
- Editor de texto puro com menus Arquivo, Editar (com Hora/Data), Pesquisar (Localizar, Localizar próxima) e Formatar (Quebra automática de linha).
- UTF-8, preservando as quebras de linha originais do arquivo.
- Usa os diálogos retrô de abrir e salvar.
- O visualizador de imagens é opcional, só se sobrar fôlego.

### Fase 7 — Temas para apps de terceiros
- **Chrome**: tema descompactado (cores cinza e azul-marinho, imagens originais) e instruções no README para carregar em `chrome://extensions`.
- **Sublime Text**: tema de interface e esquema de cores 98, instalados na pasta de pacotes.
- **Terminal.app**: perfil "Prompt" (preto, cinza e fonte retrô) para quem quiser manter o Terminal.

### Fase 8 — Navegador retrô (motor WebKit) **[decidido: WebKit, por último]**
- Janela 98 com menus, barra de ferramentas (Voltar, Avançar, Parar, Atualizar, Página inicial, Favoritos, Histórico), barra de endereço e barra de status com progresso de carregamento.
- **Abas** no estilo 98, porque são necessárias para trabalhar. **[minha escolha]**
- Downloads para `~/Downloads` com diálogo de progresso. Favoritos e histórico.
- Fica claro no README que é um navegador secundário: sem extensões do Chrome e sem compartilhar logins com o Chrome.

## 7. Instalação, atualização e desinstalação

- Requisitos: macOS 14+ e Xcode Command Line Tools.
- `git clone … && ./install.sh`
  - Menu interativo para escolher as peças.
  - Compila em modo release.
  - Instala os apps em `~/Applications/Retro98/`.
  - Registra o LaunchAgent do Shell.
  - Aplica a Fase 1 com backup.
  - Guia as permissões de Acessibilidade e Acesso Total ao Disco.
- **Atualizar**: `git pull && ./install.sh` mantém as escolhas anteriores.
- **Desinstalar**: `./uninstall.sh` restaura todas as preferências guardadas e remove apps, LaunchAgent e temas instalados.
- Assinatura: o instalador cria, na primeira vez, um certificado local estável e assina tudo com ele, para as permissões sobreviverem às atualizações (ver seção 4).

## 8. Qualidade e testes

- **Testes automatizados para a lógica**: operações de arquivo (copiar, mover, conflitos, Lixeira, interoperação de área de transferência), backup e restauração de preferências (ida e volta idêntica), montagem do menu Programas e interpretação do Executar….
- **Checklist manual por fase**, que o autor executa no próprio Mac antes de aprovar a fase seguinte.
- Testes de captura de tela dos componentes da base visual são desejáveis, não obrigatórios.

## 9. Deixado para o construtor
- Arquitetura do código (por exemplo, um pacote Swift com a base visual como biblioteca e um alvo por app) e AppKit vs. SwiftUI.
- Técnica de renderização pixel nítida (texto e ícones).
- Como desenhar os ícones (código ou PNG) e o design do logotipo original.
- A técnica exata para reservar o espaço da barra de tarefas (seção 6, Fase 2).
- Detalhes de gerenciamento de janelas via Acessibilidade.
- Ferramentas de teste e organização do repositório, CI no GitHub (desejável: build em cada PR).

## 10. Nome
- O projeto se chama **Retro98**. O nome aparece no menu Iniciar, no repositório, nos identificadores dos apps, na pasta de instalação (`~/Applications/Retro98/`) e na pasta de backup das preferências. **[decidido]**
