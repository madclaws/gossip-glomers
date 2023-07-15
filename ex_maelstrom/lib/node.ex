defmodule ExMaelstrom.Message do
  @moduledoc false

  @typedoc """
  Message format from STDIN

  - src: Client id , prefexed with "c"
  - dest: Receiving node id, prefixed with "n"
  - body: stringified json body , which should be decoded to `ExMaelstrom.MessageBody` or `ExMaelstrom.InitMessageBody`
  """
  @type t :: %__MODULE__{
          src: String.t(),
          dest: String.t(),
          body: String.t()
        }

  @derive Jason.Encoder
  defstruct(
    src: "",
    dest: "",
    body: ""
  )
end

defmodule ExMaelstrom.MessageBody do
  @moduledoc false

  @typedoc """
  One of the decoded body json string from the `ExMaelstrom.Message`

  - type: Type of the message, ex: "echo",
  - msg_id: auto incremented msg id
  - in_reply_to: msg id to which we are replying
  - code: RPC error code
  - text: RPC error code text
  """
  @type t :: %__MODULE__{
          type: String.t(),
          msg_id: integer(),
          in_reply_to: integer(),
          code: integer(),
          text: String.t()
        }

  @derive Jason.Encoder
  defstruct(
    type: "",
    msg_id: nil,
    in_reply_to: 0,
    code: nil,
    text: ""
  )
end

defmodule ExMaelstrom.InitMessageBody do
  @moduledoc false
  alias ExMaelstrom.MessageBody

  @typedoc """
  One of the decoded body json string from the `ExMaelstrom.Message`

  Represents the message body for "init" message

  - msg: message of type `ExMaelstrom.MessageBody`
  - node_id: current node id
  - node_ids: node_ids in the cluster
  """
  @type t :: %__MODULE__{
          type: String.t(),
          msg_id: integer(),
          in_reply_to: integer(),
          code: integer(),
          text: String.t(),
          node_id: String.t(),
          node_ids: list(String.t())
        }
  @derive Jason.Encoder
  defstruct(
    type: "",
    msg_id: nil,
    in_reply_to: 0,
    code: nil,
    text: "",
    node_id: "",
    node_ids: []
  )
end

defmodule ExMaelstrom.Node do
  @moduledoc """
  Node represents a sinlge node in Maelstrom network
  """
  alias ExMaelstrom.{Node, Message, MessageBody, InitMessageBody, RpcError}
  alias ExMaelstrom.Utils.IoApi
  alias ExMaelstrom.Utils.AsyncApi
  use GenServer

  require Logger

  @typedoc """
  Node struct

  - id: unique node id
  - node_ids: node ids in the maelstrom cluster
  - next_msg_id: incremental msg id counter
  - handlers - user created handler functions for message types
  - callbacks - handlers stored for each msg id
  """
  @type t :: %Node{
          id: String.t(),
          node_ids: list(String.t()),
          next_msg_id: number(),
          handlers: %{String.t() => function()},
          callbacks: %{number() => function()}
        }

  defstruct(
    id: "",
    node_ids: [],
    next_msg_id: nil,
    handlers: %{},
    callbacks: %{}
  )

  @type handler_func() :: :ok | {:error, String.t()}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets the node details
  """
  @spec info :: Node.t()
  def info do
    GenServer.call(__MODULE__, :info)
  end

  @doc """
  Registers a message handler for given message type. Multiple registration to same
  message type can raise a runtime error
  """
  @spec handle(type :: String.t(), handler_func :: handler_func()) :: :ok
  def handle(type, handler_func) do
    GenServer.cast(__MODULE__, {:handle, type, handler_func})
  end

  @spec run :: :ok
  def run do
    GenServer.cast(__MODULE__, :run)
  end

  # Genserver callbacks
  @impl true
  def init(_opts) do
    {:ok, new_node()}
  end

  @impl true
  def handle_cast({:handle, type, handler_func}, %Node{} = node) do
    case Map.has_key?(node.handlers, type) do
      false ->
        %{node | handlers: Map.put(node.handlers, type, handler_func)}
        |> then(fn node -> {:noreply, node} end)

      _ ->
        raise("duplicate message handler for #{type} message type")
        {:noreply, node}
    end
  end

  @impl true
  def handle_cast(:run, %Node{} = node) do
    Process.send_after(self(), :run_loop_proc, 100)
    {:noreply, node}
  end

  @impl true
  def handle_call(:info, _from, %Node{} = node) do
    {:reply, node, node}
  end

  @impl true
  def handle_info({:init, id, node_ids}, %Node{} = node) do
    {:noreply, init_node(node, id, node_ids)}
  end

  @impl true
  def handle_info(:run_loop_proc, %Node{} = node) do
    case run_loop(node) do
      {:ok, node} ->
        Process.send_after(self(), :run_loop_proc, 100)
        {:noreply, node}

      _ ->
        Process.send_after(self(), :run_loop_proc, 100)
        {:noreply, node}
    end
  end

  @doc """
  `init` is called to initialize the node with given `id` and `node_ids`. This is often called
   on the `init` message handler, but can also call manually for testing purposes.
  """
  @spec init_node(node :: Node.t(), id :: String.t(), node_ids :: list(String.t())) :: Node.t()
  def init_node(node, id, node_ids) do
    %Node{node | id: id, node_ids: node_ids}
  end

  # Sends a message to given destination
  @spec send_resp(body :: map(), dest :: String.t(), node :: Node.t()) ::
          :ok | {:error, term()}
  defp send_resp(body, dest, %Node{} = node) do
    with {:ok, body_json} <- Map.from_struct(body) |> Jason.encode(),
         {:ok, reply_json} =
           Jason.encode(
             Message.__struct__(
               src: node.id,
               dest: dest,
               body: body_json
             )
           ) do
      Logger.warning("Sent #{reply_json}")
      IoApi.puts(reply_json)
      :ok
    end
  end

  # sends msg response to a callback function
  @spec handle_callback(handler :: handler_func(), msg :: Message.t()) :: :ok | {:error, term()}
  def handle_callback(handler, msg) do
    with {:error, reason} <- handler.(msg) do
      Logger.error("Callback error: #{reason}")
    end
  end

  # sends msg to handler function, sends an rpc error if handler function errored out
  @spec handle_message(handler :: handler_func(), msg :: Message.t(), node) ::
          {:ok, Node.t()} | {:error, term()}
  def handle_message(handler, msg, node) do
    case handler.(msg) do
      {:error, %RpcError{} = err} ->
        reply(msg, err, node)

      {:error, err} ->
        Logger.warning("Exception handling #{inspect(msg)}:#{inspect(err)}")
        # 13 is error code for rpc crash
        reply(msg, RpcError.new_rpc_error(13, inspect(err)), node)

      _ ->
        {:ok, node}
    end
  end

  @doc false
  @spec new_node :: Node.t()
  defp new_node do
    Node.__struct__()
  end

  @spec manage_handlers(
          body :: MessageBody.t(),
          msg :: Message.t(),
          line :: String.t(),
          node :: Node.t()
        ) ::
          {:ok, Node.t()} | {:error, term()}
  defp manage_handlers(body, msg, line, node) do
    Logger.warning("Received #{inspect(msg)}")

    # if the message has in_reply_to, then basically its a reply to msg which already has a handler
    if body.in_reply_to != 0 do
      execute_callbacks(body, msg, node)
    else
      execute_handlers(body, msg, line, node)
    end
  end

  @spec execute_callbacks(body :: MessageBody.t(), msg :: Message.t(), node :: Node.t()) ::
          {:ok, Node.t()} | {:error, term()}
  defp execute_callbacks(body, msg, node) do
    handler = node.callbacks[body.in_reply_to]

    callbacks = Map.delete(node.callbacks, body.in_reply_to)
    new_node = %{node | callbacks: callbacks}

    if is_nil(handler) do
      Logger.error("Ignoring reply to #{body.in_repl_to} with no callback")
      {:error, "Ignoring reply to #{body.in_repl_to} with no callback"}
    else
      # Task.Supervisor.start_child(ExMaelstrom.TaskSupervisor, fn ->
      #   handle_callback(handler, msg)
      # end)

      AsyncApi.run(__MODULE__, :handle_callback, [handler, msg])

      # handle_callback(handler, msg)
      {:ok, new_node}
    end
  end

  @spec execute_handlers(
          body :: MessageBody.t(),
          msg :: Message.t(),
          line :: String.t(),
          node :: Node.t()
        ) :: {:ok, Node.t()} | {:error, term()}
  defp execute_handlers(body, msg, line, %Node{} = node) do
    cond do
      body.type == "init" ->
        # running sequentially, since this part will be only run at the beginning
        handle_init_message(msg, node)
      is_nil(node.handlers[body.type]) == false ->
        AsyncApi.run(__MODULE__, :handle_message, [node.handlers[body.type], msg, node])
        {:ok, node}

      true ->
        Logger.error("No handler for #{line}")
        {:error, "No handler for #{line}"}
    end
  end

  @spec handle_init_message(msg :: Message.t(), node :: Node.t()) ::
          {:ok, node} | {:error, term()}
  def handle_init_message(msg, node) do
    with {:ok, %InitMessageBody{} = body} <-
           to_struct({:ok, msg.body}, ExMaelstrom.InitMessageBody),
         %Node{} = node <- init_node(node, body.node_id, body.node_ids),
         :ok <- delegate_init_handlder(node.handlers["init"], msg) do
      Logger.info("Node #{node.id} initialized")
      # we can't call a handle_call inside handle_info, we have a possible deadlock
      reply(msg, %MessageBody{type: "init_ok", msg_id: body.msg_id}, node)
    else
      # IO.inspect(err)
      err ->
        {:error, inspect(err)}
    end
  end

  @spec to_struct(result :: {:ok, term()} | {:error, term()}, struct_passed :: term()) ::
          {:ok, term()} | {:error, term()}
  defp to_struct({:ok, res}, struct_passed) do
    {:ok, struct(struct_passed, res)}
  end

  defp to_struct({:error, reason}, _struct_passed) do
    {:error, reason}
  end

  @spec run_loop(Node.t()) :: {:ok, Node.t()} | {:error, term()}
  def run_loop(node) do
    line = IoApi.gets("")

    with {:ok, message} <- Jason.decode(line, keys: :atoms) |> to_struct(ExMaelstrom.Message),
         {:ok, message_body} <- {:ok, struct(ExMaelstrom.MessageBody, message.body)} do
      manage_handlers(message_body, message, line, node)
    else
      {:error, reason} ->
        Logger.error(inspect(reason))
        {:error, reason}
    end
  end

  @spec delegate_init_handlder(init_func :: handler_func(), msg :: Message.t()) ::
          :ok | {:error, term()}
  defp delegate_init_handlder(nil, _msg), do: :ok

  defp delegate_init_handlder(init_func, msg) do
    init_func.(msg)
  end

  # The goal is to get the msg_id from req message and add it to the response message
  @spec reply(Message.t(), map(), Node.t()) :: {:ok, Node.t()} | {:error, term()}
  def reply(req, body, node \\ nil)
  def reply(req, body, node) do
    node = if is_nil(node) do
      Node.info()
    else
      node
    end

    with {:ok, %MessageBody{msg_id: msg_id}} <-
           to_struct({:ok, req.body}, ExMaelstrom.MessageBody),
         true <- is_map(body),
         :ok <-
           Map.put(body, :in_reply_to, msg_id)
           |> send_resp(req.src, node) do
      # IO.inspect(node, label: :node)
      {:ok, node}
    else
      err ->
        Logger.error("Reply error is #{inspect(err)}")
        {:error, err}
    end
  end
end
