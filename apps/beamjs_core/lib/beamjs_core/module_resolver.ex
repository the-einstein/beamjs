defmodule BeamjsCore.ModuleResolver do
  @moduledoc """
  Resolves module specifiers for the QuickJS module loader.

  Module specifier patterns:
  - "beamjs:process"   -> stdlib process.js
  - "beamjs:gen_server" -> stdlib gen_server.js
  - "./foo"            -> relative file import
  - "../bar"           -> relative file import
  """

  @stdlib_modules ~w(process gen_server supervisor match pipe task agent timer console test)

  @doc "Resolve a module specifier and return {:ok, source} or {:error, reason}."
  def resolve_and_load(module_name, base_dir) do
    case resolve(module_name, base_dir) do
      {:ok, {:stdlib, path}} -> read_file(path)
      {:ok, {:file, path}} -> read_file(path)
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve("beamjs:" <> module_name, _base_dir) do
    if module_name in @stdlib_modules do
      path = stdlib_path(module_name)
      if File.exists?(path) do
        {:ok, {:stdlib, path}}
      else
        {:error, "stdlib module not found: beamjs:#{module_name}"}
      end
    else
      {:error, "unknown stdlib module: beamjs:#{module_name}"}
    end
  end

  defp resolve("." <> _ = relative, base_dir) do
    resolved = Path.expand(relative, base_dir)
    resolve_file(resolved)
  end

  defp resolve(module_name, base_dir) do
    # Try as a file path first
    path = Path.expand(module_name, base_dir)
    case resolve_file(path) do
      {:ok, _} = result -> result
      {:error, _} ->
        # Try in beamjs_modules/
        pkg_path = Path.join([base_dir, "beamjs_modules", module_name, "index.js"])
        if File.exists?(pkg_path) do
          {:ok, {:file, pkg_path}}
        else
          {:error, "module not found: #{module_name}"}
        end
    end
  end

  defp resolve_file(path) do
    extensions = ["", ".js", ".ts", ".mjs", "/index.js", "/index.ts"]
    Enum.find_value(extensions, {:error, "file not found: #{path}"}, fn ext ->
      full = path <> ext
      if File.exists?(full), do: {:ok, {:file, full}}
    end)
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} ->
        # Transpile TypeScript if needed
        content = if String.ends_with?(path, ".ts") or String.ends_with?(path, ".tsx") do
          BeamjsCore.Transpiler.strip_types(content)
        else
          content
        end
        {:ok, content}
      {:error, reason} ->
        {:error, "cannot read #{path}: #{reason}"}
    end
  end

  defp stdlib_path(module_name) do
    Application.app_dir(:beamjs_core, "priv/js_stdlib/#{module_name}.js")
  end
end
