defmodule Cli.Renders.Account do
  @moduledoc """
  Renders account
  """

  alias Core.Accounts.Model.Account

  def render(accounts) when is_list(accounts) and accounts != [] do
    pre_rendered_accounts = Enum.map(accounts, &render/1)

    if Mix.env() == :test do
      pre_rendered_accounts
    else
      Enum.each(pre_rendered_accounts, &IO.puts/1)
    end
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
