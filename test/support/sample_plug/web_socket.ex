defmodule SamplePlug.WebSocket.EchoServer do
  @moduledoc false

  def init(_args) do
    {:ok, []}
  end

  def handle_in({"ping", [opcode: :text]}, state) do
    {:reply, :ok, {:text, "pong"}, state}
  end

  def terminate(:timeout, state) do
    {:ok, state}
  end
end

defmodule SamplePlug.WebSocket do
  @moduledoc """
  A sample plug with WebSocket support.

  ## How to start the server?

      webserver = {Plug.Cowboy, plug: SamplePlug.WebSocket, scheme: :http, port: 4000}
      {:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)

  ## How to connect to the server?

  ### Use the console of Web browser

      ```javascript
      let sock  = new WebSocket("ws://localhost:4000/")
      sock.addEventListener("message", console.log)
      sock.addEventListener("open", () => sock.send("ping"))
      ```

  """

  import Plug.Conn
  alias __MODULE__.EchoServer

  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, _opts) do
    conn
    |> WebSockAdapter.upgrade(EchoServer, [], timeout: 60_000)
    |> halt()
  end
end
