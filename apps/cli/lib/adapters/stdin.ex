defmodule Cli.Adapters.Stdin do
  @moduledoc """
  Stdin adapter
  """

  @behaviour Cli.Ports.Stdin
  @impl true
  def read_data do
    IO.read(:stdio, :line)
    |> read_stdin_line([])
  end

  defp read_stdin_line(:eof, lines), do: Enum.reverse(lines)

  defp read_stdin_line(data, lines) when is_binary(data) do
    read_stdin_line(IO.read(:stdio, :line), [data | lines])
  end
end
