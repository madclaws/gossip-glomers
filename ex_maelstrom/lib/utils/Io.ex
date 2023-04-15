defmodule ExMaelstrom.Utils.Io do
  @moduledoc """
  IO functions
  """

  @spec gets(data :: String.t()) :: String.t()
  def gets(data) do
    IO.gets(data)
  end

  @spec puts(data :: String.t()) :: :ok
  def puts(data) do
    IO.puts(data)
  end
end

defmodule ExMaelstrom.Utils.IoApi do
  @moduledoc """
  Mox module for `ExMaelstrom.Utils.Io`
  """

  @callback gets(String.t()) :: String.t()
  @callback puts(String.t()) :: :ok

  def gets(data), do: impl().gets(data)
  def puts(data), do: impl().puts(data)

  defp impl, do: Application.get_env(:ex_maelstrom, :Io, ExMaelstrom.Utils.Io)
end
