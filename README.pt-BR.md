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
| 3B | Explorer: copiar, mover, renomear, excluir | planejada |
| 3C | Explorer: modos de exibição, busca, Abrir com, Propriedades | planejada |
| 4 | Prompt (terminal) | planejada |
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

O instalador pergunta quais peças você quer (ajustes base, barra de tarefas com o Explorer), compila tudo no seu Mac (sem conta de desenvolvedor e sem aviso de "desenvolvedor não identificado"), guarda o valor original de cada ajuste que vai mudar e depois instala. `./install.sh --yes` repete as escolhas anteriores (ou instala tudo na primeira vez).

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

## Explorer (Fase 3A)

O Retro98 Explorer é um gerenciador de arquivos no estilo 98, instalado junto com a barra de tarefas (`~/Applications/Retro98/Retro98 Explorer.app`). É um app separado: o Finder continua funcionando como sempre.

- Abra pelo botão de Início rápido ao lado do Iniciar, por Iniciar › Programas › Retro98 › Retro98 Explorer, ou por um link: `open retro98-explorer://desktop` (também `retro98-explorer://my-computer` e `retro98-explorer://folder?path=/Applications`).
- Ele abre na **Área de Trabalho**: Meu Computador, Meus Documentos, Lixeira e os arquivos da sua pasta Mesa, em ícones grandes. A mesa e os widgets do macOS não são tocados.
- Na tela: árvore de pastas à esquerda, barra de ferramentas, barra de endereço e barra de status (objetos, tamanho da seleção, espaço livre). No endereço, digite um caminho (`~/Downloads`) ou o nome de um local ("Meu Computador"); a seta lista as pastas acima da atual.
- Meu Computador mostra os discos, pen drives e volumes de rede, e se atualiza quando você pluga ou ejeta um. Pastas abertas se atualizam sozinhas quando os arquivos mudam.
- Clique duplo ou Enter abre: pastas abrem na própria janela, arquivos e apps abrem no app de sempre do macOS. A barra de espaço espia a seleção com o Visualização Rápida.
- Atalhos: ⌘[ Voltar · ⌘] Avançar · ⌘↑ ou Backspace Acima · ⌘↓ Abrir · ⇧⌘D Área de Trabalho · ⇧⌘C Meu Computador · ⇧⌘O Meus Documentos · ⌥⌘L Downloads · ⌘R Atualizar · ⌘N Nova janela · ⌘W Fechar · ⌘A Selecionar tudo.
- **Acesso Total ao Disco (opcional, só para a Lixeira):** o macOS protege a pasta da Lixeira. O instalador abre Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco e mostra o app no Finder: ative o Retro98 Explorer (ou arraste-o para a lista). Sem isso, a janela da Lixeira oferece "Abrir no Finder".
- Nas próximas entregas: copiar, mover, renomear, nova pasta, excluir para a Lixeira e desfazer (3B); modos lista e detalhes, ordenação, busca, ejetar, Abrir com e Propriedades (3C).

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

## Licença

[MIT](LICENSE)
