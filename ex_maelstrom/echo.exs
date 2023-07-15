Mix.install([:jason])

defmodule Echo do
  defstruct(
    node_id: nil,
    next_msg_id: 0
  )

  def main do
    IO.puts("Online")
    echo = Echo.__struct__()
    line = IO.gets("")
    {:ok, req} = Jason.decode(line, keys: :atoms)
    IO.puts("Received #{inspect req}")

    body = req.body
    case body.type do
      "init" ->
        %{echo | node_id: body.node_id}
        IO.puts("Initialized node #{inspect body.node_id}")
        reply(req, %{type: :init_ok}, echo)
      "echo" ->
        IO.puts("Echoing #{inspect body}")
        reply(req, %{type: "echo_ok", echo: body.echo}, echo)
    end
  end

  defp reply(request, body, echo) do
    echo =  %{echo | next_msg_id: echo.next_msg_id + 1}
    id = echo.next_msg_id
    body = Map.put(body, :msg_id, id)
    |> Map.put(:in_reply_to, request.body.msg_id)
    msg = %{src: echo.node_id, dest: request.src, body: body}
    IO.puts(Jason.encode!(msg))
    # IO.puts("\n")
  end
end

Echo.main()
