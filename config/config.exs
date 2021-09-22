import Config

# Here should be only the configs that don't care about env

for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

import_config "#{Mix.env()}.exs"
