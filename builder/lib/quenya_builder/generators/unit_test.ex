defmodule QuenyaBuilder.Generator.UnitTest do
  @moduledoc """
  Generate unit tests based on spec
  """

  require DynamicModule
  alias QuenyaBuilder.Util

  def gen(method, path, data, app, name, opts \\ []) do
    [req: req, params: params, res: res, security_data: security_data] = data
    mod_name = Util.gen_test_name(app, name)
    mod_hook = Module.concat("Elixir", Util.gen_test_hook_name(app, name))

    router_mod = Module.concat("Elixir", Util.gen_router_name(app))
    preamble = gen_preamble(router_mod)
    contents = gen_tests(mod_hook, method, path, router_mod, req.content, params, res, security_data)

    DynamicModule.gen(mod_name, preamble, contents, opts)
  end

  def gen_preamble(router) do
    quote do
      use ExUnit.Case, async: true
      use Plug.Test
      use ExUnitProperties

      import Mock

      alias Quenya.{RequestHelper, ResponseHelper, TestHelper}
      alias ExJsonSchema.Validator
      alias QuenyaTest.HookHelper

      @opts apply(unquote(router), :init, [[]])
    end
  end

  defp gen_tests(mod_hook, method, path, router_mod, content, params, res, security_data) do
    quote do
      HookHelper.ensure_loaded(unquote(mod_hook))
      property unquote(path) <> ": should work" do
        check all(
                uri <- TestHelper.stream_gen_uri(path(), params()),
                req_headers <- TestHelper.stream_gen_req_headers(params()),
                req_body <- TestHelper.stream_gen_req_body(content()),
                {code, res_header_schemas, accept, res_body_schema} <-
                  TestHelper.stream_gen_res(res())
              ) do
          conn =
            case req_body do
              nil ->
                conn(method(), uri)

              {type, data} ->
                method()
                |> conn(uri, ResponseHelper.encode(type, data))
                |> put_req_header("content-type", type)
                |> put_req_header("accept", accept)
            end

          conn =
            Enum.reduce(req_headers, conn, fn {k, v}, acc ->
              put_req_header(acc, k, v)
            end)

          conn = conn |> RequestHelper.put_security_scheme(security_data())

          HookHelper.run_precondition(mod_hook())
          mocks = HookHelper.get_mocks(mod_hook())

          conn = with_mocks mocks do
            apply(router_mod(), :call, [conn, @opts])
          end

          HookHelper.run_cleanup(mod_hook())

          assert conn.status == code

          case ResponseHelper.decode(accept, conn.resp_body) do
            "" -> nil
            v -> assert Validator.valid?(res_body_schema, v)
          end

          Enum.map(res_header_schemas, fn {name, schema} ->
            assert(
              Validator.valid?(
                schema,
                RequestHelper.get_param(conn, name, "resp_header", schema.schema)
              )
            )
          end)
        end
      end

      def mod_hook, do: unquote(mod_hook)
      def method, do: unquote(method)
      def path, do: unquote(path)
      def content, do: unquote(content)
      def params, do: unquote(params)
      def res, do: unquote(res)
      def router_mod, do: unquote(router_mod)
      def security_data, do: unquote(security_data)

    end
  end
end
