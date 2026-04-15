defmodule Mix.Tasks.Compile.BeamjsNif do
  use Mix.Task.Compiler

  def run(_args) do
    c_src = Path.join(File.cwd!(), "apps/beamjs_nif/c_src")

    if File.dir?(c_src) do
      {result, exit_code} = System.cmd("make", [], cd: c_src, stderr_to_stdout: true)
      IO.puts(result)

      if exit_code == 0 do
        {:ok, []}
      else
        {:error, [%Mix.Task.Compiler.Diagnostic{
          file: "apps/beamjs_nif/c_src/Makefile",
          severity: :error,
          message: "NIF compilation failed",
          position: 0,
          compiler_name: "beamjs_nif"
        }]}
      end
    else
      {:ok, []}
    end
  end
end
