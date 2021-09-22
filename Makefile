shell:
	@iex -S mix

deps:
	@mix deps.get

coveralls:
	@mix coveralls

setup:
	@mix deps.get
	@mix test

build_container:
	@chmod +x gen_cli_binary.sh
	@docker-compose build --no-cache
	@docker-compose up

init:
	@chmod +x gen_cli_binary.sh
	@docker-compose -f docker-compose.yaml up

authorizer_cli: 
	@cd apps/cli/ && mix escript.build && cd - && mv apps/cli/cli .
	@mv cli authorizer