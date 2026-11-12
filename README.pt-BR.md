# Retro98

**Um ambiente estilo Windows 98 para macOS que nunca atrapalha o seu trabalho.**

[Read in English](README.md)

O macOS não aceita temas de sistema, então o Retro98 não é um tema. É um conjunto de ajustes reversíveis do macOS mais apps originais no estilo 98 que rodam por cima do macOS e convivem com ele. Tudo pode ser desfeito de uma vez.

> Inspirado no Windows 98. Sem afiliação nem endosso da Microsoft. Todas as imagens e sons são originais.

## Situação

| Fase | O quê | Estado |
|---|---|---|
| 1 | Ajustes base | ✅ disponível |
| 2A | Base visual + barra de tarefas e menu Iniciar | ✅ disponível |
| 2B | Botões das janelas na barra, Dock escondido | ✅ disponível |
| 2C | Ícones na área de trabalho | substituída pela Área de Trabalho do Explorer (a mesa e os widgets do macOS ficam como estão) |
| 3A | Explorer: navegar pelos arquivos | ✅ disponível |
| 3B | Explorer: copiar, mover, renomear, excluir | ✅ disponível |
| 3C | Explorer: modos de exibição, busca, Abrir com, Propriedades | ✅ disponível |
| 4 | Prompt (terminal) | ✅ disponível |
| 5 | Painel de Controle | planejada |
| 6 | Bloco de Notas | planejada |
| 7 | Temas para Chrome, Sublime Text e Terminal.app | planejada |
| 8 | Navegador retrô (WebKit) | planejada |

## Requisitos

- macOS 14 (Sonoma) ou mais novo. Desenvolvido e testado no macOS 27 (Apple Silicon).
- Ferramentas de Linha de Comando do Xcode: `xcode-select --install`

## Instalar

```bash
git clone https://github.com/matheushchaves/retro98.git
cd retro98
./install.sh
```

O instalador pergunta quais peças você quer (ajustes base, barra de tarefas com o Explorer, o Prompt), compila tudo no seu Mac (sem conta de desenvolvedor e sem aviso de "desenvolvedor não identificado"), guarda o valor original de cada ajuste que vai mudar e depois instala. `./install.sh --yes` repete as escolhas anteriores (ou instala tudo na primeira vez); uma peça nova, como o Prompt, entra junto, a menos que você a tenha recusado antes.

## Desinstalar

```bash
./uninstall.sh
```

Isso devolve todos os valores originais. Os arquivos do Retro98 só são removidos **se tudo foi restaurado**. Se algo não puder ser restaurado, o backup fica em `~/Library/Application Support/Retro98/` e você pode rodar `./uninstall.sh` de novo.

## Barra de tarefas e menu Iniciar (Fase 2A)

Uma barra de tarefas estilo 98 na base da tela principal:

- **Iniciar** abre o menu: Programas (todos os apps do Mac, nas pastas deles), Documentos (arquivos abertos recentemente), Configurações (Ajustes do Sistema), Ajuda, Executar… (abre app, pasta, documento ou endereço pelo nome) e Desligar… (desligar, reiniciar, encerrar sessão ou repouso).
- **Control-Esc** (⌃⎋) abre e fecha o menu Iniciar.
- O canto direito mostra volume, bateria e relógio (passe o mouse para ver a data); clicar abre o painel correspondente dos Ajustes do Sistema.
- O Dock fica escondido enquanto a barra estiver ligada (não aparece nem mostra nomes); o ⌘Tab continua funcionando. Ele volta exatamente como era quando você desinstala.
- Se a barra cair, ela volta sozinha. Se cair 3 vezes em 1 minuto, ela se desliga e devolve o Dock.
- Para manter os ajustes base e tirar só a barra, rode `./install.sh` de novo e responda "n" na pergunta da barra.

Na primeira vez que você usar Desligar…, o macOS pergunta se o Retro98 Shell pode controlar o System Events.

## Botões de janela (Fase 2B)

- Um botão por janela aberta no Space atual, com o ícone do app e o título da janela.
- Clique num botão para trazer a janela para a frente; clique no botão da janela ativa para minimizá-la; clique no botão de uma janela minimizada para restaurá-la.
- Clique com o botão direito para Restaurar, Minimizar e Fechar.
- Janelas maximizadas, em "Preencher" ou lado a lado param no topo da barra em vez de passar por baixo dela.

Isso precisa da permissão de **Acessibilidade**. Na primeira vez, o Retro98 Shell explica e abre Ajustes do Sistema › Privacidade e Segurança › Acessibilidade: ative o Retro98 Shell. Você faz isso uma vez só: o instalador assina o Shell com um certificado local (guardado num chaveiro próprio, `~/Library/Keychains/retro98-signing.keychain-db`), então o macOS lembra a permissão entre atualizações. Desinstalar remove esse chaveiro; você também pode tirar o Retro98 Shell da lista de Acessibilidade.

## Explorer (Fase 3)

O Retro98 Explorer é um gerenciador de arquivos no estilo 98, instalado junto com a barra de tarefas (`~/Applications/Retro98/Retro98 Explorer.app`). É um app separado: o Finder continua funcionando como sempre.

- Abra pelo botão de Início rápido ao lado do Iniciar, por Iniciar › Programas › Retro98 › Retro98 Explorer, ou por um link: `open retro98-explorer://desktop` (também `retro98-explorer://my-computer` e `retro98-explorer://folder?path=/Applications`).
- Ele abre na **Área de Trabalho**: Meu Computador, Meus Documentos, Lixeira e os arquivos da sua pasta Mesa. A mesa e os widgets do macOS não são tocados.
- Na tela: árvore de pastas à esquerda, barra de ferramentas, barra de endereço e barra de status (objetos, tamanho da seleção, espaço livre). No endereço, digite um caminho (`~/Downloads`) ou o nome de um local ("Meu Computador"); a seta lista as pastas acima da atual.
- Meu Computador mostra os discos, pen drives e volumes de rede, e se atualiza quando você pluga ou ejeta um. Pastas abertas se atualizam sozinhas quando os arquivos mudam.
- Clique duplo, ⌘O ou ⌘↓ abre: pastas abrem na própria janela, arquivos e apps abrem no app de sempre do macOS. A barra de espaço espia a seleção com o Visualização Rápida.

### Ver e procurar (3C)

- **Modos de exibição:** ícones grandes, ícones pequenos, lista e detalhes (⌘1 a ⌘4, o menu Exibir ou o botão Modos). A lista rola para o lado. Em Detalhes, as colunas Nome, Tamanho, Tipo e Modificado ordenam com um clique, e um segundo clique inverte; Exibir › Organizar por… faz o mesmo nos outros modos. O modo e a ordem valem para todas as janelas e ficam guardados.
- **Arquivos ocultos:** Exibir › Mostrar arquivos ocultos (⇧⌘.). Eles aparecem esmaecidos, como no 98.
- **Procurar** (⌘F): abre a barra "Procurar" abaixo do endereço. Digitar filtra a pasta na hora; com **Incluir subpastas**, a busca entra nas subpastas em segundo plano (até 5.000 resultados) e Detalhes ganha a coluna "Em pasta". **Parar** interrompe e Esc fecha. **Iniciar › Localizar…** abre uma janela já procurando na sua pasta pessoal.
- **Propriedades** (⌘I ou ⌥↩︎): tipo, local, tamanho (o de pastas é calculado em segundo plano), o que a pasta contém e as datas. Em discos e pen drives, o espaço usado e o livre.
- **Abrir com:** botão direito › Abrir com, com o app padrão primeiro e "Outro…" para escolher qualquer app. Também em Arquivo › Abrir com….
- **Ejetar** (⌘E): em Meu Computador, para pen drives e volumes de rede. Se o disco estiver em uso, aparece o motivo.

### Mexendo nos arquivos (3B)

- **Copiar, recortar e colar** funcionam junto com o Finder: copie de um lado e cole do outro. Um item recortado fica esmaecido até você colar, e colar move. **⌥⌘V** move o que foi copiado (no Explorer ou no Finder), como o "Mover Item Para Cá" do Finder.
- **Arrastar e soltar** entre janelas do Explorer, para o Finder e do Finder, e de outros apps (fotos do Fotos, anexos do Mail). No mesmo disco, arrastar move; para outro disco, copia. Segure **⌥** para copiar ou **⌘** para mover. Soltar sobre uma pasta, sobre Meus Documentos, sobre um disco ou sobre a Lixeira manda para lá.
- **Renomear** com **Enter** ou **F2** (ou o menu de contexto). O nome sem a extensão já vem selecionado; mudar a extensão pede confirmação. **Nova pasta** (⇧⌘N) já entra renomeando.
- **Excluir** (⌘⌫ ou Del) pergunta e manda para a Lixeira do macOS. **Excluir permanentemente** (⌥⌘⌫ ou ⇧Del) pergunta e apaga de vez. Na janela da Lixeira, **Restaurar** devolve os itens ao lugar de onde vieram, e **Esvaziar Lixeira** (⇧⌘⌫) pergunta e esvazia.
- **Substituir:** se já existe um item com o mesmo nome, o Explorer pergunta (Sim, Sim para todos, Não, Cancelar), mostrando o tamanho e a data dos dois. O item substituído vai para a Lixeira, não some.
- **Operações longas** mostram um diálogo de progresso com Cancelar; a janela continua usável enquanto isso. Cancelar não deixa arquivo pela metade.
- **Desfazer** (⌘Z, ou o botão Desfazer) vale para o app inteiro: desfaz colar, mover, renomear, nova pasta, excluir e restaurar; ⇧⌘Z refaz. Desfazer uma cópia manda a cópia para a Lixeira, como no Finder.
- O botão direito abre o menu de contexto do item ou do fundo da janela.
- Limites: "Restaurar" só conhece o que o próprio Explorer mandou para a Lixeira (o resto volta pelo "Devolver" do Finder; o macOS não oferece isso a outros apps). A janela da Lixeira mostra e esvazia só a Lixeira do seu disco; itens apagados de pen drives o Finder esvazia. Arrastar do Fotos ou do Mail não entra no Desfazer.
- **Acesso Total ao Disco (opcional, só para a Lixeira):** o macOS protege a pasta da Lixeira: ver a Lixeira precisa dele, e restaurar, esvaziar ou desfazer uma exclusão podem precisar. O instalador abre Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco e mostra o app no Finder: ative o Retro98 Explorer (ou arraste-o para a lista). Sem isso, a janela da Lixeira oferece "Abrir no Finder".

### Atalhos do Explorer

| Ação | Teclas |
|---|---|
| Voltar, Avançar, Acima | ⌘[ · ⌘] · ⌘↑ ou Backspace |
| Abrir | duplo clique, ⌘O ou ⌘↓ |
| Área de Trabalho, Meu Computador, Meus Documentos, Downloads | ⇧⌘D · ⇧⌘C · ⇧⌘O · ⌥⌘L |
| Ícones grandes, ícones pequenos, lista, detalhes | ⌘1 · ⌘2 · ⌘3 · ⌘4 |
| Mostrar arquivos ocultos | ⇧⌘. |
| Procurar | ⌘F (Esc fecha) |
| Propriedades | ⌘I ou ⌥↩︎ |
| Ejetar | ⌘E |
| Copiar, recortar, colar | ⌘C · ⌘X · ⌘V |
| Mover o que foi copiado | ⌥⌘V |
| Desfazer, refazer | ⌘Z · ⇧⌘Z |
| Nova pasta | ⇧⌘N |
| Renomear | Enter ou F2 |
| Mandar para a Lixeira | ⌘⌫ ou Del |
| Excluir permanentemente | ⌥⌘⌫ ou ⇧Del |
| Esvaziar Lixeira | ⇧⌘⌫ |
| Atualizar, nova janela, fechar, selecionar tudo | ⌘R · ⌘N · ⌘W · ⌘A |

### Explorer no lugar do Finder (opcional)

Quando outro app pede "Mostrar no Finder" (os downloads do Safari, por exemplo), o macOS pode abrir o Retro98 Explorer, com o arquivo já selecionado.

- **Ligar:** o instalador pergunta, quando você escolhe a barra de tarefas; a resposta padrão é Não.
- **Desligar:** rode `./install.sh` de novo e responda Não, ou desinstale. O Finder volta a ser usado antes de o Explorer sair do disco.
- **Limites:** apps que já estavam abertos podem precisar ser reabertos para perceber a troca. Abrir uma pasta com dois cliques em outros apps continua indo para o Finder. Um interruptor no Painel de Controle chega na Fase 5.

## Prompt (Fase 4)

O Retro98 Prompt é um terminal completo numa janela no estilo 98 (`~/Applications/Retro98/Retro98 Prompt.app`): texto cinza-claro sobre preto, numa fonte VGA clássica desenhada com os pixels nítidos. Ele roda o seu próprio shell (`$SHELL`, como login, igual ao Terminal), então seus atalhos, seu prompt e suas ferramentas estão todos lá.

- **Abrir:** em Iniciar › Programas › Retro98 › Retro98 Prompt, pelo Spotlight ou com `open -a "Retro98 Prompt"`. O instalador pergunta por ele separado da barra de tarefas (a resposta padrão é Sim).
- **Janelas, não abas:** ⌘N abre outra janela, cada uma com o seu shell. Fechar uma janela (⌘W ou o botão ×) com um programa rodando (vim, ssh, um build) pergunta antes; um shell parado fecha na hora, e digitar `exit` fecha a janela. Encerrar o app pergunta uma vez se alguma janela tiver programa rodando.
- **O de sempre de um terminal:** copiar e colar com ⌘C/⌘V (selecione com o mouse), 10.000 linhas de histórico pela barra de rolagem retrô ou pelo trackpad, cores ANSI e 256 cores, Unicode e acentos. O Option digita caracteres (é, ã, ü) em vez de funcionar como Meta. Redimensione a janela e as linhas acompanham.
- **Não substitui o Terminal:** o Terminal continua sendo o app que abre arquivos `.command` e `.sh`, e nada nele muda. Um perfil do Terminal com o mesmo visual chega na Fase 7.

| Ação | Atalho |
|---|---|
| Nova janela, fechar | ⌘N · ⌘W |
| Copiar, colar, selecionar tudo | ⌘C · ⌘V · ⌘A |
| Minimizar | ⌘M |

## O que a Fase 1 muda

| Id | Ajuste | O que muda |
|---|---|---|
| `wallpaper` | Fundo verde-água sólido | O papel de parede vira `#008080` sólido em todas as telas |
| `lightAppearance` | Modo claro | Aparência clara, sem troca automática |
| `colors` | Destaque grafite e seleção azul-marinho | Cor de destaque grafite, seleção de texto `#000080` |
| `contrast` | Menos transparência e mais contraste | Menus e barras laterais opacos, controles com contorno |
| `pointer` | Ponteiro branco com contorno preto | Preenchimento branco, contorno preto |
| `scrollBars` | Barras de rolagem sempre visíveis | As barras de rolagem não somem mais |
| `windowAnimations` | Sem animações de janela | Janelas abrem e fecham na hora |
| `titleBarDoubleClick` | Duplo clique na barra de título maximiza | O duplo clique preenche a tela |
| `finderExplorer` | Finder no jeito do Explorer | Barra de status, barra de caminho, todas as extensões, pastas primeiro, lista, novas janelas na pasta pessoal |

Aplique ou desfaça ajustes um a um com a ferramenta instalada:

```bash
TOOL="$HOME/Library/Application Support/Retro98/bin/retro98-settings"
"$TOOL" status
"$TOOL" apply --only colors,pointer
"$TOOL" restore --only lightAppearance
```

## Permissões e problemas conhecidos

- Para trocar para o modo claro na hora, o macOS pode perguntar se o **Terminal pode controlar o System Events**. Se você recusar, o modo claro vale depois de sair e entrar de novo na conta.
- Os ajustes de Acessibilidade (`contrast`, `pointer`) precisam de **Acesso Total ao Disco** para o app de terminal em que você roda o instalador. Se o macOS recusar, a ferramenta abre **Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco**: ative o seu app de terminal e rode o mesmo comando de novo. Os outros ajustes são aplicados normalmente. Use o mesmo app de terminal para desinstalar.
- Alguns apps só mostram as novas cores, barras de rolagem ou animações depois de fechados e abertos de novo.

## Créditos

- **Fonte do Prompt:** PxPlus IBM VGA 8x16, do [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/), de VileR, sob a licença [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.pt-br). A fonte e a licença dela ficam em `Resources/Prompt/` e vão dentro do app. É a versão "Plus" porque a original, da página de código 437, não tem ã nem õ.
- **Motor do terminal:** [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), de Miguel de Icaza, licença MIT, incluído na versão 1.11.2 em `Vendor/SwiftTerm` com três pequenas correções trazidas do SwiftTerm 1.19 (fonte de pixel nítida, espaço para a nossa barra de rolagem e perceber quando o shell termina). As versões mais novas precisam do Metal Toolchain, que se baixa à parte do Xcode, e quebrariam a instalação na maioria dos Macs; os detalhes estão em `Vendor/SwiftTerm/VENDORED.md`.

## Licença

[MIT](LICENSE) para o código do próprio Retro98. A fonte do Prompt mantém a licença CC BY-SA 4.0, e o SwiftTerm, a MIT.
