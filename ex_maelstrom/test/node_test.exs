defmodule NodeTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  alias ExMaelstrom.Node
  alias ExMaelstrom.RpcError
  alias ExMaelstrom.RpcErrorCodes

  describe "test node run" do
    setup do
      node_pid = start_link_supervised!(Node)
      {:ok, %{nid: node_pid}}
    end

    test "starting node", %{nid: nid} do
      assert %Node{} = :sys.get_state(nid)
    end

    test "manual initialization of node", %{nid: _nid} do
      node = :sys.get_state(Process.whereis(Node))
      assert %Node{id: "1", node_ids: ["3", "4"]} = Node.init_node(node, "1", ["3", "4"])
    end

    @tag :skip
    test "Malinformed input json" do
      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, fn _ ->
        "\n"
      end)

      node = Node.info()
      # logs = capture_log(fn -> Node.run_loop(node) end)
      # Node.run_loop(node)
      assert {:error, %Jason.DecodeError{}} = Node.run_loop(node)
    end

    # @tag :skip
    test "Error missing handler" do
      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, fn _ ->
        """
        {"dest":"n1", "body":{"type":"echo", "msg_id":1}}
        """ <> "\n"
      end)

      node = Node.info()

      # logs = capture_log(fn -> Node.run_loop(node) end)

      # assert String.contains?(logs, "No handler for " <> """
      # {"dest":"n1", "body":{"type":"echo", "msg_id":1}}
      # """) == true

      assert {:error, "No handler for" <> _} = Node.run_loop(node)
    end

    @tag :rpc
    test "Return RPC error" do
      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, fn _ ->
        """
        {"dest":"n1", "body":{"type":"foo", "msg_id":1000}}
        """ <> "\n"
      end)
      |> expect(:puts, fn dat ->
        IO.puts(dat)
      end)

      ExMaelstrom.MoxAsyncInteractor
      |> expect(:run, fn m, f, a ->
        apply(m, f, a)
      end)

      Node.handle("foo", fn _msg ->
        %RpcErrorCodes{} = rpc_error_codes = RpcErrorCodes.new()
        {:error, RpcError.new_rpc_error(rpc_error_codes.not_supported, "bad call")}
      end)

      node = Node.info()

      logs = capture_log(fn -> Node.run_loop(node) end)

      assert String.contains?(logs, "10") == true
    end

    @tag :non_rpc
    test "Return NON-RPC error" do
      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, fn _ ->
        """
        {"dest":"n1", "body":{"type":"foo", "msg_id":1000}}
        """ <> "\n"
      end)
      |> expect(:puts, fn dat ->
        IO.puts(dat)
      end)

      ExMaelstrom.MoxAsyncInteractor
      |> expect(:run, fn m, f, a ->
        apply(m, f, a)
      end)

      Node.handle("foo", fn _msg ->
        {:error, "bad call"}
      end)

      node = Node.info()

      logs = capture_log(fn -> Node.run_loop(node) end)

      assert String.contains?(logs, "13") == true
    end
  end

  describe "test node run init" do
    setup do
      node_pid = start_link_supervised!(Node)
      {:ok, %{nid: node_pid}}
    end

    @tag :init
    test "init handler" do
      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, 2, fn _ ->
        """
        {"dest":"n1", "body":{"type":"init", "msg_id":1, "node_id": "n3", "node_ids": ["n1", "n2", "n3"]}}
        """ <> "\n"
      end)
      |> expect(:puts, 2, fn dat ->
        IO.puts(dat)
      end)

      Node.handle("init", fn _msg ->
        :ok
      end)

      node = Node.info()
      logs = capture_log(fn -> Node.run_loop(node) end)
      assert String.contains?(logs, "init_ok") == true
      assert {:ok, node} = Node.run_loop(node)
      assert node.id == "n3"
      assert node.node_ids == ["n1", "n2", "n3"]
    end
  end

  describe "test run echo" do
    setup do
      node_pid = start_link_supervised!(Node)
      {:ok, %{nid: node_pid}}
    end

    @tag :echo
    test "run echo" do
      Node.handle("echo", fn msg ->
        body = struct(ExMaelstrom.MessageBody, msg.body)

        Map.put(body, :type, "echo_ok")
        |> then(&Node.reply(msg, &1))
      end)

      Process.send(Process.whereis(Node), {:init, "n1", ["n1"]}, [])
      node = Node.info()

      ExMaelstrom.MoxIoInteractor
      |> expect(:gets, fn _ ->
        """
        {"dest":"n1", "body":{"type":"echo", "msg_id": 2}}
        """ <> "\n"
      end)
      |> expect(:puts, fn dat ->
        IO.puts(dat)
      end)

      ExMaelstrom.MoxAsyncInteractor
      |> expect(:run, fn m, f, a ->
        apply(m, f, a)
      end)

      logs = capture_log(fn -> Node.run_loop(node) end)
      assert String.contains?(logs, "echo_ok") == true
    end
  end
end
