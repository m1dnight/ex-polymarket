defmodule Polymarket.Schemas.ClobErrorTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.ClobError

  describe "from_response/2" do
    test "extracts the error message from a map body" do
      error = ClobError.from_response(400, %{error: "not enough balance / allowance"})

      assert error.status == 400
      assert error.error == "not enough balance / allowance"
      assert error.code == nil
      assert error.retry_after_seconds == nil
    end

    test "captures a machine-readable code and retry hint (post-only mode)" do
      error =
        ClobError.from_response(503, %{
          error: "post-only mode",
          code: "post_only_mode",
          retry_after_seconds: 79
        })

      assert error.status == 503
      assert error.code == "post_only_mode"
      assert error.retry_after_seconds == 79
    end

    test "also accepts string keys" do
      error = ClobError.from_response(401, %{"error" => "Invalid API key"})

      assert error.error == "Invalid API key"
    end

    test "stringifies a non-map body so nothing is lost" do
      assert ClobError.from_response(500, "could not insert order").error ==
               "could not insert order"

      assert ClobError.from_response(502, ["weird"]).error == ~s(["weird"])
    end
  end
end
