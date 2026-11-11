# Retro98

**Um ambiente estilo Windows 98 para macOS que nunca atrapalha o seu trabalho.**

[Read in English](README.md)

O macOS não aceita temas de sistema, então o Retro98 não é um tema. É um conjunto de ajustes reversíveis do macOS mais apps originais no estilo 98 que rodam por cima do macOS e convivem com ele. Tudo pode ser desfeito de uma vez.

> Inspirado no Windows 98. Sem afiliação nem endosso da Microsoft. Todas as imagens e sons são originais.

## Situação

| Fase | O quê | Estado |
|---|---|---|
| 1 | Ajustes base (esta versão) | ✅ disponível |
| 2 | Base visual + Shell (área de trabalho, barra de tarefas, menu Iniciar) | planejada |
| 3 | Explorer (gerenciador de arquivos) | planejada |
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

O instalador compila tudo no seu Mac (sem conta de desenvolvedor e sem aviso de "desenvolvedor não identificado"), guarda o valor original de cada ajuste que vai mudar e depois aplica os ajustes da Fase 1. Use `./install.sh --yes` para pular a pergunta.

## Desinstalar

```bash
./uninstall.sh
```

Isso devolve todos os valores originais. Os arquivos do Retro98 só são removidos **se tudo foi restaurado**. Se algo não puder ser restaurado, o backup fica em `~/Library/Application Support/Retro98/` e você pode rodar `./uninstall.sh` de novo.

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
- Se o macOS recusar um ajuste de Acessibilidade (`contrast`, `pointer`), a ferramenta abre **Ajustes do Sistema › Acessibilidade › Tela** para você mudar à mão. Os outros ajustes são aplicados normalmente.
- Alguns apps só mostram as novas cores, barras de rolagem ou animações depois de fechados e abertos de novo.

## Licença

[MIT](LICENSE)
