<p align="center">
  <img src="assets/logo/logo_completa.png" alt="Cyberdeck" width="640">
</p>

<p align="center">
  Um jogo de cartas educativo sobre decisões de segurança digital para usuários não especialistas.
</p>

## Sobre

No Cyberdeck, o jogador enfrenta ameaças digitais como phishing e vazamento de credenciais escolhendo cartas que representam práticas de segurança. Algumas cartas são boas práticas. Outras são atalhos inseguros que rendem mais pontos na hora, mas abrem **brechas de segurança** que continuam causando prejuízo nas jogadas e rodadas seguintes.

A ideia central do jogo é mostrar que a consequência de uma decisão insegura raramente aparece no mesmo momento em que ela é tomada.

O projeto é desenvolvido como Trabalho de Conclusão de Curso do Bacharelado em Ciência da Computação da Universidade Estadual de Maringá (UEM), com o título *Gamificação na Segurança Digital: Desenvolvimento e Avaliação de um Jogo Eletrônico para Conscientização de Usuários*. O design partiu de uma Revisão Sistemática da Literatura sobre jogos sérios em segurança digital.

**Situação atual:** versão inicial funcional. A avaliação experimental com o público-alvo é a próxima etapa.

## Como jogar

Cada rodada apresenta uma ameaça com um **Índice de Risco**. O objetivo é alcançar esse valor em pontos usando no máximo três jogadas, com até três cartas por jogada.

A pontuação de uma jogada é calculada assim:

```
pontuação = soma da Proteção das cartas × produto da Vulnerabilidade das cartas
```

A Proteção soma e a Vulnerabilidade multiplica. As cartas de má prática têm Proteção baixa e Vulnerabilidade alta, então parecem vantajosas: multiplicam a jogada inteira. O custo vem depois.

### Brechas de segurança

Cartas de má prática abrem brechas, que seguem este ciclo:

1. **Abertura.** A brecha é aberta pela carta insegura, mas só começa a valer a partir da jogada seguinte.
2. **Penalidade.** Enquanto a brecha estiver aberta, cada jogada perde uma porcentagem da pontuação.
3. **Persistência.** A brecha continua aberta entre rodadas e entre cenários.
4. **Exploração.** Ameaças de rodadas posteriores podem explorar uma brecha aberta, e isso aumenta o Índice de Risco daquela rodada.
5. **Correção.** Cartas específicas de boa prática fecham a brecha.

Se o jogador perde uma rodada, as brechas voltam ao estado em que estavam no início dela.

## Conteúdo

### Cenários

| Cenário | Tema | Brecha principal | Chefe |
|---|---|---|---|
| E-mail suspeito | Phishing, anexos e links maliciosos | Dispositivo comprometido | O Imitador |
| Senhas | Reutilização de senhas e vazamento de credenciais | Credenciais expostas | A Chave-Mestra |
| Programa gratuito | Adware, instaladores com extras e notificações | Navegador sequestrado | O Anunciante |

Cada cenário tem três rodadas e termina com a batalha contra um chefe, vencida respondendo perguntas sobre o tema. Cada rodada tem um baralho próprio, e as cartas novas vão sendo apresentadas aos poucos.


### Cartas


| Carta | Proteção | Vulnerabilidade | Efeito |
|---|---|---|---|
| Senha Forte | 35 | ×1.0 | |
| Utilizar senhas exclusivas | 55 | ×1.0 | Fecha *Credenciais expostas* |
| Usar Gerenciador de Senhas | 35 | ×1.3 | |
| Trocar Senha Vazada | 30 | ×1.2 | Fecha *Credenciais expostas* |
| Autenticação em Dois Fatores | 20 | ×1.5 | |
| Não Repassar o Código | 25 | ×1.5 | |
| Verificar o Remetente | 30 | ×1.5 | |
| Antivírus Atualizado | 40 | ×1.0 | Fecha *Dispositivo comprometido* e *Navegador sequestrado* |
| Instalação Personalizada | 30 | ×1.3 | |
| Revisar Extensões | 25 | ×1.2 | Fecha *Navegador sequestrado* |
| Bloquear Notificações | 20 | ×1.5 | |
| Reutilizar Senha | 10 | ×2.0 | Abre *Credenciais expostas* |
| Senha de Aniversário | 10 | ×2.0 | Abre *Credenciais expostas* |
| Anotar Senha no Monitor | 15 | ×1.8 | Abre *Credenciais expostas* |
| Clicar em Link Suspeito | 5 | ×2.0 | Abre *Dispositivo comprometido* |
| Abrir Anexo Desconhecido | 10 | ×2.0 | Abre *Dispositivo comprometido* |
| Clicar em Baixar | 10 | ×2.0 | Abre *Dispositivo comprometido* |
| Instalação Rápida | 10 | ×2.0 | Abre *Navegador sequestrado* |
| Permitir Notificações | 15 | ×1.8 | Abre *Navegador sequestrado* |


## Recursos

- **Tutorial guiado** por um assistente, com destaque visual nos elementos da interface que estão sendo explicados.
- **Painel educativo**: ao passar o mouse sobre uma carta, aparece uma explicação sobre a prática que ela representa.
- **Enciclopédia**, acessível pelo menu principal e pelo menu de pausa, dividida em capítulos por ameaça. Cada capítulo explica como a ameaça funciona, traz links para as cartilhas do CERT.br e mostra as cartas relacionadas, indicando quais são boas práticas e quais abrem brechas. Uma aba final reúne todas as cartas por categoria. As cartas que ainda não apareceram ficam bloqueadas, com as informações substituídas por `?`.
- **Tela Como jogar**, no menu principal e no menu de pausa, com as regras, a fórmula de pontuação e os controles.
- **Tela de conclusão de cada cenário**, com pontuação, brechas abertas e corrigidas, tempo e a lista das cartas que apareceram.
- **Opções**: volume geral e modo para daltonismo (protanopia, deuteranopia e tritanopia), com intensidade ajustável. As opções ficam salvas entre uma execução e outra.
- **Narrativa** com a vilã E.V.E, apresentada em ligações entre os cenários.
- **Registro de métricas de sessão**, usado na avaliação experimental (detalhes abaixo).

## Como executar

### Versão pronta

Baixe o arquivo da sua plataforma na página de [Releases](https://github.com/lucasfratus/cyberdeck/releases), descompacte e execute. Não é preciso instalar o Godot.

### Pelo código-fonte

**Requisito:** [Godot Engine](https://godotengine.org/) 4.7.1.

1. Clone o repositório:
   ```
   git clone https://github.com/lucasfratus/cyberdeck.git
   ```
2. Abra o Godot e importe o projeto selecionando o arquivo `project.godot`.
3. Pressione **F5** para executar. O jogo começa pelo menu principal.

O projeto usa o renderizador de compatibilidade (GL Compatibility).

### Controles

| Ação | Comando |
|---|---|
| Selecionar e jogar cartas | Mouse |
| Ver a explicação de uma carta | Passar o mouse sobre a carta |
| Avançar um diálogo | Clique na caixa de diálogo, botão *Continuar* ou Enter |
| Pausar | Esc |

# Ferramentas para a avaliação experimental

Em build de depuração, que inclui a execução pelo editor e as exportações com a opção *Exportar com Depuração*, o jogo mostra recursos voltados às sessões de avaliação:

- **Nome do participante**, pedido depois de *Jogar*. Ele identifica o arquivo de métricas e permite relacioná-lo às respostas dos questionários.
- **Abrir pasta das sessões**, no canto inferior direito do menu principal, que abre a pasta onde os registros são gravados.
- **Limpar coleção**, na Enciclopédia, que apaga o registro de cartas encontradas para o próximo participante começar do zero.
- **Menu de desenvolvedor**, aberto com **Ctrl + Shift + D** no menu principal. Ele começa a partida direto em qualquer rodada ou chefe de qualquer cenário, com a dificuldade escolhida. Não tem botão na tela, para não aparecer para os participantes.

Cada sessão gera um arquivo JSON em `user://sessions/`, gravado de novo a cada evento. No topo do arquivo ficam o nome do participante, a dificuldade e o modo para daltonismo usados. Os eventos registram o início e o fim de cenários e rodadas, cada jogada com as cartas usadas, as práticas inseguras, a pontuação e as brechas abertas ou fechadas, o tempo de leitura dos painéis educativos, as aberturas da pausa, da Enciclopédia e da tela Como jogar, os capítulos consultados, os links abertos, as respostas aos chefes e as janelas de anúncio fechadas ou clicadas. O bloco `summary` traz os totais já calculados.

## Estrutura do projeto

```
assets/        fontes, ícones, ilustrações das cartas, logo, shaders e temas
data/          conteúdo do jogo em Resources: brechas, diálogos, rodadas e cenários
gameplay/      regras: baralho, rodada, pontuação e dados de cenário e rodada
globals/       identificadores de cartas, nomes de categorias e paleta de cores
managers/      autoloads: banco de cartas, coleção de cartas encontradas e registro de sessão
scenes/        cenas e scripts: partida, cartas, mão, diálogos, enciclopédia e menus
tests/         cenas de teste dos componentes de cartas, mão e baralho
```

O conteúdo fica separado da lógica. Cartas, brechas, rodadas, cenários e diálogos são Resources (`.tres`) editáveis pelo inspetor do Godot. Para adicionar uma carta ou uma rodada, não é preciso alterar código.

## Créditos

Desenvolvido por **Lucas de Oliveira Fratus**, sob orientação do **Prof. Dr. Alisson Renan Svaigen** e **Prof. Me. Felippe Fernandes da Silva**, no Departamento de Informática da Universidade Estadual de Maringá.

- Parte das ilustrações das cartas e os personagens foram gerados pelo autor com IA (**Google Gemini**).
- Sons das cartas: [UI SFX](https://github.com/romainsimon/uisfx), de Romain Simon (CC0).
- Correção para daltonismo: shader de Vildravn, publicado no [Godot Shaders](https://godotshaders.com/shader/colorblindness-correction-shader/) (CC0).
- Fontes: Atkinson Hyperlegible e Atkinson Hyperlegible Mono, do Braille Institute (SIL Open Font License 1.1).
- Motor: [Godot Engine](https://godotengine.org/).

A origem de cada arquivo está em [creditos.md](creditos.md).
