defmodule SamplePlug.General do
  @moduledoc """
  A sample plug.

  ## How to start the server?

      webserver = {Plug.Cowboy, plug: SamplePlug.General, scheme: :http, port: 4000}
      {:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)

  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(_opts) do
    # This part of the code was intentionally constructed to test the
    # init/1 process.
    [resp: "Plug: Hello, World!"]
  end

  @impl true
  def call(conn, opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, opts[:resp])
  end
end
