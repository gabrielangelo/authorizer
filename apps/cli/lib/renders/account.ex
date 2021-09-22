defmodule Cli.Renders.Account do
  @moduledoc """
  Renders account
  """

  alias Core.Accounts.Model.Account

  def render(accounts) when is_list(accounts) and accounts != [] do
    Enum.map(accounts, &render/1)
    |> List.flatten()
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
