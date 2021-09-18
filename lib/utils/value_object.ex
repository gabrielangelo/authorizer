defmodule Core.Authorizer.Utils.ValueObject do
  @moduledoc "ValueObject helper"

  alias Ecto.Changeset

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false

      @type t :: Ecto.Schema.t() | %__MODULE__{}
    end
  end

  @iso8601_structs [
    Date,
    DateTime,
    NaiveDateTime,
    Time
  ]

  @default_action :validation

  def is_value_object?(mod) do
    function_exported?(mod, :changeset, 1)
  end

  @type cast_and_apply_result :: {:ok, struct} | {:error, Ecto.Changeset.t()}

  @spec cast_and_apply(struct) :: cast_and_apply_result
  @spec cast_and_apply(struct | map(), atom | module() | (map() -> Ecto.Changeset.t())) ::
          cast_and_apply_result
  @spec cast_and_apply(
          struct | map(),
          atom | module() | (map() -> Ecto.Changeset.t()),
          action :: atom
        ) :: cast_and_apply_result

  def cast_and_apply(%_mod{} = input), do: cast_and_apply(input, @default_action)

  def cast_and_apply(%mod{} = input, action) do
    input
    |> encode()
    |> cast_and_apply(mod, action)
  end

  def cast_and_apply(input, changeset_fn) when is_function(changeset_fn, 1),
    do: cast_and_apply(input, changeset_fn, @default_action)

  def cast_and_apply(input, mod), do: cast_and_apply(input, mod, @default_action)

  def cast_and_apply(input, changeset_fn, action)
      when is_function(changeset_fn, 1) do
    input
    |> changeset_fn.()
    |> Changeset.apply_action(action)
  end

  def cast_and_apply(input, mod, action) do
    input
    |> encode()
    |> mod.changeset()
    |> Changeset.apply_action(action)
  end

  @spec encode(input :: struct() | map(), key_type :: :string_keys | :atom_keys) :: map()
  def encode(input, key_type \\ :string_keys) do
    input
    |> Map.new(fn
      {key, value} -> {cast_key(key, key_type), do_cast_to_map(value, key_type)}
    end)
  end

  defp do_cast_to_map(%schema{} = struct, _key_type) when schema in @iso8601_structs, do: struct

  defp do_cast_to_map(%_schema{} = struct, key_type) do
    struct
    |> Map.from_struct()
    |> do_cast_to_map(key_type)
  end

  defp do_cast_to_map(map, key_type) when is_map(map) do
    map
    |> Map.drop([:__meta__])
    |> Map.to_list()
    |> Enum.map(fn
      {k, v} -> {cast_key(k, key_type), do_cast_to_map(v, key_type)}
    end)
    |> Enum.into(%{})
  end

  defp do_cast_to_map(list, key_type) when is_list(list) do
    Enum.map(list, fn
      {k, v} -> {cast_key(k, key_type), do_cast_to_map(v, key_type)}
      v -> do_cast_to_map(v, key_type)
    end)
  end

  defp do_cast_to_map(value, _key_type), do: value

  defp cast_key(key, :atom_keys), do: to_atom(key)
  defp cast_key(key, :string_keys), do: to_string(key)

  defp to_atom(v) when is_atom(v), do: v

  defp to_atom(v) do
    v
    |> String.replace("-", "_")
    |> String.to_existing_atom()
  end
end
