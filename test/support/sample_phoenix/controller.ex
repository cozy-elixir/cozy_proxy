defmodule SamplePhoenix.Controller do
  @moduledoc false

  use Phoenix.Controller

  def index(conn, _) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Phoenix: Hello, World!")
  end
end
