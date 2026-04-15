defmodule BeamjsCliTest do
  use ExUnit.Case

  test "main with no args shows usage" do
    # Just verify it doesn't crash
    assert capture_io(fn -> BeamjsCli.main([]) end) =~ "BeamJS"
  end

  test "main with version flag" do
    assert capture_io(fn -> BeamjsCli.main(["version"]) end) =~ "BeamJS v0.1.0"
  end

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
