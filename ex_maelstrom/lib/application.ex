defmodule ExMaelstrom.Application do
  @moduledoc false

  use Application
  require Logger
  alias ExMaelstrom.Echo
  @impl true
  def start(_type, _args) do
    Logger.info("Starting ExMaelstrom node")

    children = [
      {Task.Supervisor, name: ExMaelstrom.TaskSupervisor},
      {Echo, []}
    ]

    opts = [strategy: :one_for_one, name: ExMaelstrom.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
