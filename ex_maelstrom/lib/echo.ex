defmodule ExMaelstrom.Echo do
  @moduledoc false

  alias ExMaelstrom.Node
  alias ExMaelstrom.Message

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: :__MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}, {:continue, :main}}
  end

  @impl true
  def handle_continue(:main, state) do
    {:ok, _} = Node.start_link([])

    Node.handle("echo", fn %Message{} = msg ->
      struct(ExMaelstrom.MessageBody, msg.body)
      |> Map.put(:type, "echo_ok")
      |> then(&Node.reply(msg, &1))
    end)

    Node.run()
    {:noreply, state}
  end
end
