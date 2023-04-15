defmodule ExMaelstrom.Utils.Commons do
  @moduledoc """
  Utilities for testing
  """

  @doc """
  Converts keys of a map which has string type to atom
  """
  @spec to_atom_keys(map()) :: map()
  def to_atom_keys(string_key_map) do
    Map.new(string_key_map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
