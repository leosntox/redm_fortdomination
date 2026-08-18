# redm_fortdomination

Missão configurável de domínio de fortes para servidores **RedM** que utilizam o framework **VORP**.

O jogador encontra um informante, aceita a missão e segue até o forte indicado. Ao entrar na área, uma onda de inimigos é iniciada. Eliminando todos os inimigos, o jogador conquista o forte, torna-se seu Dominador e recebe acesso ao armário, às recompensas e ao gerenciamento de membros.

> **Status:** versão `0.4.6 Beta`. O fluxo principal foi testado com sucesso. Os testes completos com múltiplos jogadores ainda estão em andamento.

## Funcionalidades

- Informante com posição fixa ou sorteada.
- Cinco modelos configuráveis para o informante.
- Mudança automática e configurável da posição e do modelo do informante.
- Prompt para aceitar a missão.
- Forte, áreas, distâncias e tempos configuráveis.
- Blip temporário indicando o forte da missão.
- Cooldown global persistente iniciado ao aceitar a missão.
- Tempo máximo configurável para chegar ao forte.
- Ondas de inimigos configuráveis.
- Quantidade, vida, precisão e munição dos inimigos configuráveis.
- Modelos, armas e pontos de surgimento sorteados para cada inimigo.
- Lista de armas específica para cada ponto de surgimento.
- Intervalo configurável entre o surgimento dos inimigos e entre as ondas.
- Metade dos inimigos ataca o iniciador e a outra metade procura jogadores presentes na área.
- Validação no servidor da distância até o informante e da chegada ao forte.
- Registro e validação dos inimigos pelo `Network ID`.
- Conquista liberada somente após a morte de todos os inimigos registrados.
- Proteção contra conclusão falsa da missão por eventos do cliente.
- Novas ondas são interrompidas se o iniciador morrer ou abandonar a área.
- Inimigos vivos permanecem no local e continuam procurando jogadores após o fracasso.
- Remoção controlada dos NPCs nativos do forte durante o combate.
- Preservação de NPCs marcados como entidades de missão por outros recursos.
- Limpeza automática dos cadáveres da missão.
- Limpeza dos inimigos abandonados se o iniciador desconectar.
- Posse persistente do forte.
- Armário compartilhado e persistente usando `vorp_inventory`.
- Suporte a itens e armas no armário.
- Recompensas configuráveis em dinheiro ou itens.
- Itens de recompensa depositados diretamente no armário.
- Recompensa alternativa em dinheiro se os itens não couberem no armário.
- Menu administrativo separado do armário.
- Cadastro de jogadores próximos como membros do forte.
- Limite de membros configurável.
- Permissões separadas para armário e futura bancada de fabricação.
- Interface e notificações em português do Brasil.

## Dependências

- `vorp_core`
- `vorp_inventory` V2
- `vorp_menu` 1.3 ou superior
- `oxmysql`

## Instalação

1. Baixe e extraia o arquivo da versão desejada.
2. Copie a pasta `redm_fortdomination` para a pasta de recursos do servidor.
3. Não altere o nome da pasta do recurso.
4. Confirme que todas as dependências estão instaladas e funcionando.
5. Adicione os recursos ao `server.cfg` nesta ordem:

```cfg
ensure oxmysql
ensure vorp_core
ensure vorp_inventory
ensure vorp_menu
ensure redm_fortdomination
```

6. Reinicie o servidor.

As tabelas necessárias são criadas automaticamente quando o recurso inicia. O arquivo completo também está disponível em:

```text
sql/redm_fortdomination.sql
```

Normalmente não é necessário executar o SQL manualmente em uma instalação nova.

## Estrutura do recurso

```text
redm_fortdomination/
├── client/
│   └── main.lua
├── config/
│   ├── config.lua
│   └── forts.lua
├── languages/
│   └── pt_br.lua
├── server/
│   └── main.lua
├── sql/
├── fxmanifest.lua
└── README.md
```

## Como funciona

1. O informante aparece na posição configurada.
2. O jogador segura a tecla de interação para aceitar a missão.
3. O cooldown global começa imediatamente.
4. Um blip indica o forte que deve ser atacado.
5. Ao entrar na área de ativação, o combate começa.
6. Os inimigos surgem gradualmente nos pontos configurados.
7. O jogador precisa eliminar todos os inimigos da onda.
8. Ao concluir a última onda, o jogador torna-se o novo Dominador.
9. Uma recompensa configurável é sorteada.
10. O novo Dominador recebe acesso ao armário e ao menu administrativo.

## Cooldown

O cooldown é global por forte e começa quando a missão é aceita, independentemente de vitória ou derrota.

O valor padrão é de duas horas:

```lua
Config.GlobalCooldownSeconds = 7200
```

Para testes, você pode reduzir temporariamente esse valor. Exemplo de um minuto:

```lua
Config.GlobalCooldownSeconds = 60
```

## Configuração geral

As principais opções estão em `config/config.lua`. Nesse arquivo é possível configurar:

- duração do cooldown e tempo máximo para chegar ao forte;
- tecla e distância do prompt;
- posição, modelos e mudança automática do informante;
- modelos, vida, precisão, munição e comportamento dos inimigos;
- intervalos de surgimento, novas ondas e limpeza;
- controle dos NPCs nativos;
- limite e distância para adicionar membros;
- margens de validação do servidor.

Exemplo das características padrão dos inimigos:

```lua
Config.EnemyDefaults = {
    health = 100,
    accuracy = 50,
    weaponAmmo = 999,
    combatRange = 2,
    combatAbility = 2,
    combatMovement = 2,
    spawnSpread = 2.5,
    spawnInterval = 1000,
    nextWaveDelay = 5000,
    corpseCleanupDelay = 60000,
    failedRetargetInterval = 3000,
}
```

## Configuração do forte

As áreas, ondas, pontos de surgimento, armas, armário e recompensas estão em `config/forts.lua`.

É possível configurar:

- nome e centro do forte;
- raios de ativação, combate e segurança;
- tempo para retornar à área;
- blip da missão;
- quantidade de ondas e inimigos;
- pontos de surgimento e armas disponíveis;
- posição, capacidade e identificador do armário;
- posição do menu administrativo;
- recompensas em itens ou dinheiro.

## Armário do forte

O armário usa um inventário personalizado e persistente do `vorp_inventory`.

Identificador padrão:

```text
fort_domination_fort_wallace
```

O conteúdo permanece armazenado mesmo após reiniciar o servidor ou trocar o Dominador. A capacidade, o nome e a permissão para guardar armas podem ser alterados em `config/forts.lua`.

> Não altere o identificador do armazenamento depois de começar a utilizá-lo. Um identificador diferente será tratado como outro armário.

## Dominador e membros

Ao concluir a missão, o iniciador torna-se o novo Dominador do forte.

O Dominador pode:

- acessar o armário;
- abrir o menu administrativo;
- adicionar jogadores próximos;
- remover membros;
- permitir ou bloquear o acesso de cada membro ao armário;
- preparar permissões para a futura bancada de fabricação.

Quando um jogador é adicionado, as permissões de armário e bancada são ativadas por padrão. Apenas o Dominador pode administrar os membros.

Uma nova conquista substitui o Dominador anterior e remove todos os membros cadastrados pela posse anterior. O conteúdo do armário não é apagado.

## Recompensas

Uma opção é sorteada após cada conquista. As recompensas podem ser:

- dinheiro entregue diretamente ao novo Dominador;
- itens depositados no armário;
- valor alternativo em dinheiro caso os itens não possam ser armazenados.

Todas as opções podem ser alteradas em `config/forts.lua`.

## Comportamento em caso de fracasso

A missão fracassa quando:

- o iniciador morre;
- o iniciador permanece fora da área permitida por mais tempo que o configurado;
- o tempo máximo para chegar ao forte termina;
- o iniciador desconecta.

Após morte ou abandono, novas ondas não são criadas. Os inimigos vivos da onda atual permanecem no local e continuam atacando jogadores presentes na área até serem eliminados.

Em caso de desconexão do iniciador, os inimigos registrados são removidos após o tempo configurado para evitar entidades abandonadas no servidor.

## Banco de dados

O recurso utiliza duas tabelas próprias:

- `fort_domination_ownership`: posse, conquista, cooldown e recompensa;
- `fort_domination_members`: membros e permissões.

O conteúdo do armário é armazenado pelo próprio `vorp_inventory`.

## Atualização

Antes de atualizar:

1. Faça uma cópia de segurança da pasta atual.
2. Faça backup do banco de dados.
3. Leia as notas da nova versão.
4. Substitua os arquivos do recurso.
5. Execute uma migração SQL somente se as notas solicitarem.
6. Reinicie o servidor.

Não altere o identificador do armário durante uma atualização.

## Versão 0.4.6

- Corrigida incompatibilidade que interrompia a onda após o primeiro inimigo.
- Mantido o registro seguro dos inimigos pelo `Network ID`.
- Validação de distância até o informante e o forte.
- Validação da quantidade, modelo, área e morte dos inimigos.
- Limpeza programada de cadáveres e entidades abandonadas.
- Proteção adicional para NPCs controlados por outros recursos.

## Status dos testes

Testado com sucesso:

- aceitação da missão no informante;
- chegada e ativação do Forte Wallace;
- surgimento dos inimigos;
- combate e conclusão da onda;
- entrega da recompensa;
- registro do novo Dominador;
- abertura do armário;
- abertura do menu administrativo;
- cadastro de membros no menu.

Ainda recomendado testar com múltiplos jogadores:

- acesso de membro autorizado ao armário;
- bloqueio e liberação da permissão do armário;
- divisão dos alvos entre os jogadores;
- morte do iniciador com outros jogadores na área;
- desconexão durante o combate;
- nova conquista substituindo o Dominador anterior.

## Observações

- Este recurso está em desenvolvimento e pode receber alterações futuras.
- Faça testes em um servidor de desenvolvimento antes de utilizar em produção.
- Mantenha backups da pasta e do banco de dados antes de atualizar.
