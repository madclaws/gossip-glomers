defmodule ExMaelstrom.Utils.Async do
  @moduledoc false

  @spec run(atom(), function(), list()) :: term()
  def run(module, func, arity) do
    Task.Supervisor.start_child(ExMaelstrom.TaskSupervisor, fn ->
      apply(module, func, arity)
    end)
  end
end

defmodule ExMaelstrom.Utils.AsyncApi do
  @moduledoc """
  Mox module for `ExMaelstrom.Utils.Io`
  """

  @callback run(atom(), function(), list()) :: term()

  def run(module, func, arity), do: impl().run(module, func, arity)

  defp impl, do: Application.get_env(:ex_maelstrom, :async, ExMaelstrom.Utils.Async)
end
