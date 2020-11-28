defmodule Quenya.Loader do
  @moduledoc """
  Load the fixture file
  """
  alias QuenyaUtil.Parser
  alias Quenya.Builder.Router

  def load(name) do
    {:ok, result} =
      File.cwd!()
      |> Path.join("test/fixture/#{name}/main.yml")
      |> Parser.parse()

    result
  end

  def gen, do: gen(load("todo"))

  def gen(data) do
    path = File.cwd!() |> Path.join("gen")

    Router.gen(data, :quenya_todo, path: Path.join(path, "todo"))
    # Enum.each(data["paths"], fn {uri, ops} ->
    #   Enum.each(ops, fn {method, _doc} ->
    #     Request.gen(data, uri, method, :quenya_todo, path: Path.join(path, "request"))
    #   end)
    # end)
  end
end
