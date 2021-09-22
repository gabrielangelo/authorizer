defmodule Cli.Ports.Stdin do
  @moduledoc """
  Stdin Port
  """

  @callback read_data :: [String.t()]

  @spec read_data :: [String.t()]
  def read_data do
    implementation().read_data()
  end

  defp implementation do
    :cli
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:implementation)
  end
end
