# Authorizer
 Uma CLI escrita em Elixir  que autoriza transações para uma conta específica seguindo uma
série de regras predefinidas.

## Features
  
1. Criação de conta
2. Autorização de transação
3. Leitura de linhas do Stdin
4. Renderização de accounts

## Setup

Fazendo setup local.

```$ make setup```

#### Docker Compose

Presumindo que já tenha o Docker e Docker Compose instalado, execute o comando abaixo.  

```$ make build_container```

## Modelo da Arch
![Arch_ER](https://github.com/gabrielangelo/authorizer/blob/master/arch.png)

 1. Cli.Scripts.Authorizer: Cria uma coleção de dados (strings) lidas do stdin através do módulo Cli.Ports.Stdin
 2. Cli.Scripts.Authorizer realiza um decode para Map de cada entrada da coleção gerada pelo Cli.Ports.Stdin
 3. Cli.Readers.AuhtorizerReader realiza um processamento de acordo com a estrutura da coleção. Os casos cobertos são criação de contas e autorização dee transações.
 4. Cada caso irá chamar uma módulo apropriado (  Core.Transactions.AuthorizeTransactions para autorização de transação ou Core.Accounts.CreateAccount para criação de conta)
 5. Cada execute será um processo que será executado em paralelo, após a execução completa, os outputs serão renderizados por Cli.Renders.Account

## Testes

Testes podem ser executados:

Local:

```$ mix test```

Docker:
```
$ docker-compose run app mix test
```

Pode-se ver a cobertura dos testes utilizando o seguinte commando:

Local:

```$ mix coveralls```

Docker:

```$ docker-compose run app mix coveralls```

## Gerando o authorizer bin
Local:
- instruções irão gerar um arquivo chamado `"authorizer"`;

```
  $ chmod +x gen_authorizer_cli.sh
  $ ./gen_authorizer_cli
```

Docker: 
 
 O`"authorizer"` já vem gerado automaticamente dentro do container após o build.

## Execução
Local: 
``` $ authorizer < {file}.json```

Docker:
``` $ docker-compose run app authorizer < {file}.json```

**Obs:**
Pode-se usar o arquivo `"operations_sample.json"` para um primeiro caso de teste.
