


# Authorizer

Uma CLI escrita em Elixir que autoriza transações para uma conta específica seguindo uma

série de regras predefinidas.

  

## Features

  

1. Criação de conta

2. Autorização de transação

3. Leitura de linhas do Stdin

4. Renderização de accounts

  

## Setup

  

Fazendo setup local.

  

-  ```$ make setup```

  

#### Docker Compose

  

Presumindo que já tenha o Docker e Docker Compose instalado, execute o comando abaixo.

  

-  ```$ make build_container```

  

## Testes

  

Testes podem ser executados:

  

Local:

  

-  ```$ mix test```

  

Docker:

-  ```$ docker-compose run app mix test```

  

Pode-se ver a cobertura dos testes utilizando o seguinte commando:

  

Local:

  

-  ```$ mix coveralls```

  

Docker:

  

-  ```$ docker-compose run app mix coveralls```

  

## Gerando o authorizer bin

Local:

- As abaixo instruções irão gerar um arquivo chamado `"authorizer"`;

-  ```$ make authorizer_cli```

  

Docker:

O`"authorizer"` já vem gerado automaticamente dentro do container após o build.

  

## Execução

Local:

-  ``` $ authorizer < {file}.json```

  

Docker:

-  ``` $ docker-compose run app authorizer < {file}.json```

  

**Obs:**

Pode-se usar o arquivo `"operations_sample.json"` para um primeiro caso de teste.

  

## Organização dos módulos

[comment]: <>  (A imagem pode ser visualizada localmente acessando arquivo assets/images/arch.png)

![Arch_ER](https://github.com/gabrielangelo/authorizer/blob/master/assets/images/arch.png)

**Obs:**

A imagem pode ser visualizada localmente acessando arquivo assets/images/arch.png

1. Cli.Scripts.Authorizer: Cria uma coleção de dados (strings) lidas do stdin através do módulo Cli.Ports.Stdin;

- O módulo Cli.Ports.Stdin é uma clara implementação de um conteito de Hexagonal architecture, que é o de Port-Adapters

- Esse módulo chama uma implementação de um adapter Cli.Adapters.Stdin que é chamado fora do contexto de teste;

- Caso contrário, ele chama a implementação de um mock para simular o input de stdin nos testes de integração.

  

2. Cli.Scripts.Authorizer realiza um decode de json para Map de cada entrada da coleção gerada pelo Cli.Ports.Stdin;

3. Cli.Readers.AuhtorizerReader realiza um processamento de acordo com a estrutura da coleção. Os casos cobertos são criação de contas e autorização de transações;

4. Cada caso irá chamar um módulo apropriado (Core.Transactions.AuthorizeTransactions para autorização de transação ou Core.Accounts.CreateAccount para criação de conta), cada processo contém uma função pública .execute();

5. Cada .execute chamado será um processo que executará paralelamente com os outros executes;

6. O módulo Core.Transactions.AuthorizeTransactions chama um módulo auxiliar definido abaixo:

- Core.Transactions.Policies.TimeWindow: é o módulo responsável por aplicar as políticas de validação de janela de tempo nas transações. (high-frequency-small-interval e doubled-transaction).

7. O Core.Transactions.AuthorizeTransactions retorna as movimentações de conta que serão o input do Cli.Renders.Account.render() gerando assim o output da CLI.

## Libs externas

-  [Jason](https://github.com/michalmuskala/jason) -> decode de json para map;

-  [Ecto](https://hexdocs.pm/ecto/Ecto.html) -> criação dos models de memória de account e transaction, podendo ser extendido para modelo de banco de dados no futuro;

-  [Mox](https://github.com/dashbitco/mox) -> Criação de mocks para o stdin;

-  [Credo](https://github.com/rrrene/credo) -> Análise de código estático de código;

-  [Dialyzer](https://github.com/jeremyjh/dialyxir) -> Análise de código estático de código.

  

## Nota sobre algumas decisões técnicas

- Uso da linguagem de programação erlang/elixir para uso [BEAM](https://blog.erlang.org/a-brief-BEAM-primer/) em uma aplicação financeira.

- Trata-se de uma aplicação [umbrella](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html#umbrella-projects) que gerencia 2 aplicações:

- Core: O núcleo da regra de negócio da aplicação, nela encontra-se os modelos de conta e transação como também as rotinas do autorizador;

- Cli: A aplicação responsável por ler os dados do stdin e criar as entradas corretas para as funções de regras de negócio da aplicação Core;

- Ambas as aplicações se conversam.

- A arch foi concebida para ser basicamente um "map-reduce" de entradas que são escalonadas para diferentes processos que executam concorrentemente. A saída ( Accounts ) é um "reduce" dos outputs de cada processo. Função usada: [Task.async_stream/3](https://hexdocs.pm/elixir/1.12/Task.html#async_stream/3)

- Cada instância Core.Transactions.AuthorizeTransactions é uma operação de batch que executa uma lista de transações de uma determinada conta. Ou seja, é escalonado um processo para cada conta e suas operações ( Seja autorização de transações ou criação de contas)
- Geração de um **binário** que encapsula todo o software construído. É mais flexível para ambientes que não tem elixir instalado. Além disso, pode-se adiciona-lo no diretório /bin e usá-lo de qualquer outro dir do sistema operacional.
 
- Cada autorizador é um "pipeline" que compartilha uma esturutura definida abaixo:
	```elixir
	Core.Types.AuthorizeTransactionsHistory{
		account_movements_log: list(),
		transactions: list(),
		transactions_log: list(),
		settled_transactions_count: integer()
	}```

- `"account_movements_log"`: é a lista de movimenações bancárias realizadas por cada transação. O estado de cada movimentação com suas violações é guardado aqui;

- `"transactions"`: é a lista de transações, aqui não há alteração de estado, serve apenas para um parseamento primário;

- `"transactions_log"`: é a lista de transações processadas, essa lista é incrementada quando uma transação é liquidada ou rejeitada;

- `"settled_transactions_count"`: contador de transações liquidadas, usada na contagem de transações no apply de policy de janela de tempo.


 **Nota Adicional** 
 Pensando em alguns casos extremos, criei outra branch que tenta lidar com alguns casos que julguei ser corner-cases, como um input de transações de dias/anos diferentes onde o authorizer deveria lidar com cada conjunto de transações de um período de forma cronológica aplicando as mesmas regras:

```json
  # input
["{\"account\": {\"active-card\": true, \"available-limit\": 100}}\n",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"2019-02-13T11:00:00.000Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 20, \"time\": \"2019-02-13T11:00:01.000Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 20, \"time\": \"2019-02-13T11:01:01.000Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Subway\", \"amount\": 20, \"time\": \"2019-02-13T11:01:31.000Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 10, \"time\": \"2019-02-13T12:00:00.000Z\"}}",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 190, \"time\": \"2021-09-26 03:08:13.449719Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 5, \"time\": \"2021-09-26 03:08:13.449719Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 150, \"time\": \"2021-09-26 03:08:13.449719Z\"}}\n",
 "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 190, \"time\": \"2021-09-26 03:08:13.449719Z\"}}\n"]

 # output
 "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":80,\"violations\":[]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":60,\"violations\":[]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":40,\"violations\":[]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":40,\"violations\":[\"high_frequency_small_interval\"]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":30,\"violations\":[]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":40,\"violations\":[\"insufficient-limit\"]}}",
 "{\"account\":{\"active-card\":true,\"available-limit\":35,\"violations\":[\"doubled-transaction\",\"insufficient-limit\"]}}"]```
```
Porém para manter a simplicidade do projeto e considerando que se trata de uma operação que envolvem liquidações instantâneas, talvez não faça sentido dar suporte a esse tipo de feature no momento, logo preferi não mergear com a master deixando em aberto para decisões futuras.


