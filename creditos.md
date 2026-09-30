# Créditos

**Cyberdeck** foi desenvolvido por **Lucas de Oliveira Fratus**, sob orientação do **Prof. Dr. Alisson Renan Svaigen** e do **Prof. Me. Felippe Fernandes da Silva**, no Departamento de Informática da Universidade Estadual de Maringá (UEM), como Trabalho de Conclusão de Curso.

Este arquivo lista a origem de cada recurso visual e sonoro do jogo.

## Imagens geradas por IA pelo autor (Google Gemini)

As imagens abaixo foram geradas pelo autor com o **Google Gemini** e depois ajustadas para o jogo.

**Ilustrações de cartas** (`assets/cards/illustrations/`)

| Arquivo | Carta |
|---|---|
| `antivirus_updated.jpeg` | Antivírus Atualizado |
| `autenticacao_2fa.png` | Autenticação em Dois Fatores |
| `link_suspeito.png` | Clicar em Link Suspeito |
| `reutilizar_senha.png` | Reutilizar Senha |
| `strong_password_i.png` | Senha Forte |

**Personagens**

| Arquivo | Personagem |
|---|---|
| `assets/dialogue/assistant_sprite_placeholder.png` | Assistente (sprite dos diálogos e da batalha) |
| `assets/dialogue/assistant_portrait.png` | Assistente (retrato dos diálogos) |
| `assets/dialogue/portraits/eve_portrait.png` | E.V.E |
| `assets/dialogue/portraits/grunt_portrait.png` | ?? |

**Chefes** (`assets/icons/ui/`): A Chave-Mestra (`boss_key.png`) e O Anunciante (`boss_ad.png`). O Imitador usa a ilustração da anomalia.

**Brechas** (`assets/icons/breaches/`): `breach.png`, `compromised_device.png`, `exposed_credentials.png`, `hijacked_browser.png`.

## Logo

Os arquivos em `assets/logo/` (`.aseprite` e `.png`) foram feitos pelo autor no editor de pixel art Aseprite.

## Sons

**Sons das cartas** (`assets/audio/cards/`): pacote [UI SFX](https://github.com/romainsimon/uisfx), de Romain Simon, licença **CC0 1.0** (domínio público). A correspondência com os arquivos originais está em `assets/audio/cards/CREDITOS.txt`.

**Vozes, toques e efeitos** (`assets/audio/*.wav`): sintetizados por código em Python (NumPy e SciPy). Isso inclui as vozes dos diálogos, o grito "Eve!", o toque e o chiado das ligações e os sons do chefe.

## Código de terceiros

**Correção para daltonismo** (`assets/shaders/colorblind_correction.gdshader`): adaptado do [Colorblindness correction shader](https://godotshaders.com/shader/colorblindness-correction-shader/), de Vildravn, licença **CC0**. O algoritmo vem do daltonize.org.

## Fontes

Atkinson Hyperlegible e Atkinson Hyperlegible Mono, do Braille Institute, sob a SIL Open Font License 1.1. A licença está em `assets/fonts/OFL-AtkinsonHyperlegibleMono.txt`.

## Conteúdo educativo

Os capítulos da Enciclopédia indicam, como leitura complementar, os fascículos da [Cartilha de Segurança para Internet](https://cartilha.cert.br/), do CERT.br. O jogo só aponta para esses materiais e não reproduz o conteúdo deles.

## Motor

[Godot Engine](https://godotengine.org/) 4.7.1, licença MIT.
