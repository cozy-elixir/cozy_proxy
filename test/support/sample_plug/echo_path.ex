defmodule SamplePlug.EchoPath do
  @moduledoc """
  A plug that echos the path info from conn.

  ## How to start the server?

      webserver = {Bandit, plug: SamplePlug.EchoPath, scheme: :http, port: 4000}
      {:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)

  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: path_info} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "/" <> Enum.join(path_info, "/"))
  end
end
