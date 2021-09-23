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


## Decisões/Modelo

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

## TODOs

Veja as Issues do repositório.
