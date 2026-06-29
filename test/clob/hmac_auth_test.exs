defmodule Polymarket.Clob.HmacAuthTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.HmacAuth
  alias Polymarket.Schemas.Credentials

  # The well-known test secret used by rs-clob-client-v2's auth tests.
  @secret "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  @address Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)

  describe "sign/2 (matches rs-clob-client-v2 byte-for-byte)" do
    test "golden vector: a JSON POST-like message" do
      message = ~s(1000000test-sign/orders{"hash":"0x123"})

      assert HmacAuth.sign(@secret, message) == "4gJVbox-R6XlDK4nlaicig0_ANVL1qdcahiL8CXfXLM="
    end

    test "golden vector: an empty-body GET message" do
      assert HmacAuth.sign(@secret, "1GET/") == "eHaylCwqRSOa2LFD77Nt_SaTpbsxzN8eTEI3LryhEj4="
    end
  end

  describe "headers/6 (matches rs-clob-client-v2 l2_headers golden)" do
    test "builds the full L2 header set for an empty-body GET" do
      credentials = %Credentials{
        api_key: "00000000-0000-0000-0000-000000000000",
        secret: @secret,
        passphrase: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }

      assert HmacAuth.headers(@address, credentials, "GET", "/", "", 1) == [
               {"POLY_ADDRESS", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"},
               {"POLY_API_KEY", "00000000-0000-0000-0000-000000000000"},
               {"POLY_PASSPHRASE", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
               {"POLY_SIGNATURE", "eHaylCwqRSOa2LFD77Nt_SaTpbsxzN8eTEI3LryhEj4="},
               {"POLY_TIMESTAMP", "1"}
             ]
    end

    test "POLY_ADDRESS is checksummed (unlike the lowercase L1 header)" do
      credentials = %Credentials{api_key: "k", secret: @secret, passphrase: "p"}
      headers = Map.new(HmacAuth.headers(@address, credentials, "POST", "/order", "{}", 1))

      assert headers["POLY_ADDRESS"] == "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    end

    test "the HMAC covers timestamp, method, path and body" do
      credentials = %Credentials{api_key: "k", secret: @secret, passphrase: "p"}
      base = Map.new(HmacAuth.headers(@address, credentials, "POST", "/order", "{}", 1))

      refute base["POLY_SIGNATURE"] ==
               Map.new(HmacAuth.headers(@address, credentials, "POST", "/order", "{}", 2))[
                 "POLY_SIGNATURE"
               ]

      refute base["POLY_SIGNATURE"] ==
               Map.new(HmacAuth.headers(@address, credentials, "POST", "/order", "{} ", 1))[
                 "POLY_SIGNATURE"
               ]
    end
  end
end
