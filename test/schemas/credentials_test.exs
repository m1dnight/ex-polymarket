defmodule Polymarket.Schemas.CredentialsTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Credentials

  describe "from_attrs/1" do
    test "parses the camelCase apiKey and the secret material" do
      assert {:ok, credentials} =
               Credentials.from_attrs(%{
                 "apiKey" => "11111111-2222-3333-4444-555555555555",
                 "secret" => "c2VjcmV0",
                 "passphrase" => "a-passphrase"
               })

      assert credentials.api_key == "11111111-2222-3333-4444-555555555555"
      assert credentials.secret == "c2VjcmV0"
      assert credentials.passphrase == "a-passphrase"
    end

    test "accepts atom keys as decoded by the HTTP layer" do
      assert {:ok, credentials} =
               Credentials.from_attrs(%{apiKey: "key", secret: "s", passphrase: "p"})

      assert credentials.api_key == "key"
      assert credentials.secret == "s"
      assert credentials.passphrase == "p"
    end

    test "returns an error when a field is missing" do
      assert Credentials.from_attrs(%{"apiKey" => "key", "secret" => "s"}) ==
               {:error, :invalid_credentials}
    end

    test "returns an error when a field is not a string" do
      assert Credentials.from_attrs(%{"apiKey" => "key", "secret" => 123, "passphrase" => "p"}) ==
               {:error, :invalid_credentials}
    end
  end

  describe "inspect/1 redaction" do
    test "shows the api_key but never the secret or passphrase" do
      {:ok, credentials} =
        Credentials.from_attrs(%{
          "apiKey" => "the-key",
          "secret" => "TOP_SECRET_VALUE",
          "passphrase" => "HUSH_HUSH"
        })

      output = inspect(credentials)

      assert output =~ "the-key"
      refute output =~ "TOP_SECRET_VALUE"
      refute output =~ "HUSH_HUSH"
    end
  end
end
