defmodule Cli.Renders.Account do
  @moduledoc """
  Renders account
  """

  alias Core.Accounts.Model.Account

  def render(accounts) when is_list(accounts) do
    Enum.each(accounts, &render/1)
  end

  def render(%Account{} = account) do
    IO.puts(
      %{
        "account" => %{
          "active-card" => account.active_card,
          "available-limit" => account.available_limit,
          "violations" => account.violations
        }
      }
      |> Jason.encode!()
    )
  end
end
