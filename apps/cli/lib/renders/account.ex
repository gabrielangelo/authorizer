defmodule Cli.Renders.Account do
  @moduledoc """
  Renders account
  """

  alias Core.Accounts.Model.Account

  def render(accounts) when is_list(accounts) and accounts != [] do
    accounts = accounts
    |> Enum.map(&render/1)

    Enum.each(accounts, &IO.puts/1)

    accounts
  end

  def render([]), do: []
  def render({:ok, []}), do: []

  def render(%Account{} = account) do
    %{
      "account" => %{
        "active-card" => account.active_card,
        "available-limit" => account.available_limit,
        "violations" => account.violations
      }
    }
    |> Jason.encode!()
  end
end
