defmodule BeamjsCli.Repl do
  @moduledoc """
  Interactive REPL for BeamJS.
  Maintains a persistent QuickJS context across evaluations.
  """

  def start(_opts \\ []) do
    {:ok, ctx_ref} = BeamjsNif.new_context([])

    IO.puts("BeamJS v0.1.0 (QuickJS on BEAM/OTP #{System.otp_release()})")
    IO.puts("Type .help for help, .exit to quit\n")

    loop(ctx_ref, 1)
  end

  defp loop(ctx_ref, line_num) do
    prompt = "beamjs(#{line_num})> "

    case IO.gets(prompt) do
      :eof ->
        IO.puts("\nBye!")
      {:error, _} ->
        IO.puts("\nBye!")
      input ->
        input = String.trim(input)

        case input do
          "" ->
            loop(ctx_ref, line_num)
          ".exit" ->
            IO.puts("Bye!")
          ".quit" ->
            IO.puts("Bye!")
          ".help" ->
            print_help()
            loop(ctx_ref, line_num)
          ".clear" ->
            BeamjsNif.destroy_context(ctx_ref)
            {:ok, new_ctx} = BeamjsNif.new_context([])
            IO.puts("Context cleared.")
            loop(new_ctx, 1)
          _ ->
            case BeamjsNif.eval(ctx_ref, input, "<repl:#{line_num}>") do
              {:ok, :undefined} ->
                :ok
              {:ok, nil} ->
                :ok
              {:ok, result} ->
                IO.puts("=> #{inspect_js(result)}")
              {:error, {:js_exception, message, stack}} ->
                IO.puts(:stderr, "Error: #{message}")
                if stack != "" and stack != nil do
                  IO.puts(:stderr, stack)
                end
              {:error, reason} ->
                IO.puts(:stderr, "Error: #{inspect(reason)}")
            end
            loop(ctx_ref, line_num + 1)
        end
    end
  end

  defp inspect_js(value) when is_binary(value), do: "\"#{value}\""
  defp inspect_js(value) when is_integer(value), do: "#{value}"
  defp inspect_js(value) when is_float(value), do: "#{value}"
  defp inspect_js(true), do: "true"
  defp inspect_js(false), do: "false"
  defp inspect_js(nil), do: "null"
  defp inspect_js(:undefined), do: "undefined"
  defp inspect_js(value) when is_list(value) do
    items = Enum.map(value, &inspect_js/1) |> Enum.join(", ")
    "[#{items}]"
  end
  defp inspect_js(value) when is_map(value) do
    items = Enum.map(value, fn {k, v} -> "#{k}: #{inspect_js(v)}" end) |> Enum.join(", ")
    "{ #{items} }"
  end
  defp inspect_js(value), do: inspect(value)

  defp print_help do
    IO.puts("""

    BeamJS REPL Commands:
      .help    Show this help
      .clear   Clear the JS context (reset all state)
      .exit    Exit the REPL
      .quit    Exit the REPL

    You can evaluate any JavaScript expression:
      beamjs(1)> 1 + 2
      => 3
      beamjs(2)> const x = [1, 2, 3].map(n => n * 2)
      beamjs(3)> x
      => [2, 4, 6]
    """)
  end
end
