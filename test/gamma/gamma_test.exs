defmodule Polymarket.GammaTest do
  use ExUnit.Case, async: true

  alias Polymarket.Gamma
  alias Polymarket.Schemas.Event
  alias Polymarket.Schemas.EventMetadata
  alias Polymarket.Schemas.FeeSchedule
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.Tag

  # First market in the fixtures, kept as a (camelCase, string-keyed) map so
  # Req.Test can re-encode it as the API would. Expectations are derived from it
  # rather than hard-coded, so refreshing the fixtures can't stale the test.
  @market_attrs "test/fixtures/gamma/markets.txt"
                |> File.read!()
                |> String.split("\n", trim: true)
                |> hd()
                |> Jason.decode!()

  @market_id @market_attrs["id"]
  @market_slug @market_attrs["slug"]

  # First line of the tags fixture: a JSON array of (camelCase, string-keyed) tags.
  @tags_attrs "test/fixtures/gamma/tags.txt"
              |> File.read!()
              |> String.split("\n", trim: true)
              |> hd()
              |> Jason.decode!()

  # The keyset events fixture: a full (camelCase, string-keyed) response so
  # Req.Test can re-encode it as the API would. We slice it into small pages to
  # exercise pagination without standing up the whole payload.
  @events_attrs "test/fixtures/gamma/events_keyset.txt"
                |> File.read!()
                |> Jason.decode!()
                |> Map.fetch!("events")

  # A single event response (camelCase, string-keyed) for GET /events/:id, taken
  # from the first line of the JSONL fixture. Kept raw so Req.Test re-encodes it
  # exactly as the API would.
  @event_attrs "test/fixtures/gamma/events.txt"
               |> File.read!()
               |> String.split("\n", trim: true)
               |> hd()
               |> Jason.decode!()

  @event_id @event_attrs["id"]
  @event_slug @event_attrs["slug"]

  describe "get_market_by_id/1" do
    test "requests the right URL and parses the market on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets/#{@market_id}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{} = market} = Gamma.get_market_by_id(@market_id)
      assert market.id == @market_id
      assert market.slug == @market_attrs["slug"]
      assert market.outcomes == Jason.decode!(@market_attrs["outcomes"])
      assert Enum.all?(market.outcome_prices, &is_float/1)
      assert %DateTime{} = market.end_date
      assert %FeeSchedule{} = market.fee_schedule
      assert [%Tag{} | _] = market.tags
    end

    test "forwards query options like include_tag to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert URI.decode_query(conn.query_string) == %{"include_tag" => "true"}
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(@market_id, include_tag: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(@market_id)
    end

    test "accepts an integer id" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/markets/#{@market_id}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(String.to_integer(@market_id))
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_id("does-not-exist")
    end

    test "returns an error when the payload is not a valid market" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_id(@market_id)
    end
  end

  describe "get_market_by_slug/1" do
    test "requests the right URL and parses the market on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets/slug/#{@market_slug}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{} = market} = Gamma.get_market_by_slug(@market_slug)
      assert market.id == @market_id
      assert market.slug == @market_slug
      assert market.outcomes == Jason.decode!(@market_attrs["outcomes"])
      assert Enum.all?(market.outcome_prices, &is_float/1)
      assert %DateTime{} = market.end_date
      assert %FeeSchedule{} = market.fee_schedule
      assert [%Tag{} | _] = market.tags
    end

    test "forwards query options like include_tag to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/markets/slug/#{@market_slug}"
        assert URI.decode_query(conn.query_string) == %{"include_tag" => "true"}
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_slug(@market_slug, include_tag: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_slug(@market_slug)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_slug("does-not-exist")
    end

    test "returns an error when the payload is not a valid market" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_slug(@market_slug)
    end
  end

  describe "get_market_tags/1" do
    test "requests the right URL and parses the tags on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets/#{@market_id}/tags"
        Req.Test.json(conn, @tags_attrs)
      end)

      assert {:ok, tags} = Gamma.get_market_tags(@market_id)
      assert [%Tag{} | _] = tags
      assert length(tags) == length(@tags_attrs)

      first = hd(tags)
      expected = hd(@tags_attrs)
      assert first.id == expected["id"]
      assert first.slug == expected["slug"]
      assert %DateTime{} = first.created_at
    end

    test "accepts an integer id" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/markets/#{@market_id}/tags"
        Req.Test.json(conn, @tags_attrs)
      end)

      assert {:ok, [%Tag{} | _]} = Gamma.get_market_tags(String.to_integer(@market_id))
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_market_tags_failed} = Gamma.get_market_tags("does-not-exist")
    end

    test "returns an error when a tag in the payload is invalid" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, [%{"createdBy" => "not-an-integer"}])
      end)

      assert {:error, :get_market_tags_failed} = Gamma.get_market_tags(@market_id)
    end
  end

  describe "get_event_by_id/1" do
    test "requests the right URL and parses the event on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/events/#{@event_id}"
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{} = event} = Gamma.get_event_by_id(@event_id)
      assert event.id == @event_id
      assert event.slug == @event_attrs["slug"]
      assert is_float(event.volume)
      assert %DateTime{} = event.created_at
      assert [%Market{} | _] = event.markets
      assert %EventMetadata{} = event.event_metadata
      assert [%Tag{} | _] = event.tags
    end

    test "forwards query options like include_chat to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert URI.decode_query(conn.query_string) == %{"include_chat" => "true"}
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{}} = Gamma.get_event_by_id(@event_id, include_chat: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{}} = Gamma.get_event_by_id(@event_id)
    end

    test "accepts an integer id" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/events/#{@event_id}"
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{}} = Gamma.get_event_by_id(String.to_integer(@event_id))
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_event_failed} = Gamma.get_event_by_id("does-not-exist")
    end

    test "returns an error when the payload is not a valid event" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_event_failed} = Gamma.get_event_by_id(@event_id)
    end
  end

  describe "get_event_by_slug/1" do
    test "requests the right URL and parses the event on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/events/slug/#{@event_slug}"
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{} = event} = Gamma.get_event_by_slug(@event_slug)
      assert event.id == @event_id
      assert event.slug == @event_slug
      assert is_float(event.volume)
      assert %DateTime{} = event.created_at
      assert [%Market{} | _] = event.markets
      assert %EventMetadata{} = event.event_metadata
      assert [%Tag{} | _] = event.tags
    end

    test "forwards query options like include_chat to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/events/slug/#{@event_slug}"
        assert URI.decode_query(conn.query_string) == %{"include_chat" => "true"}
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{}} = Gamma.get_event_by_slug(@event_slug, include_chat: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @event_attrs)
      end)

      assert {:ok, %Event{}} = Gamma.get_event_by_slug(@event_slug)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_event_failed} = Gamma.get_event_by_slug("does-not-exist")
    end

    test "returns an error when the payload is not a valid event" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_event_failed} = Gamma.get_event_by_slug(@event_slug)
    end
  end

  describe "list_events/1" do
    test "requests the right URL and parses a page of events on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/events/keyset"
        Req.Test.json(conn, %{"events" => @events_attrs, "next_cursor" => "CURSOR2"})
      end)

      assert {:ok, %{events: events, next_cursor: "CURSOR2"}} = Gamma.list_events()
      assert length(events) == length(@events_attrs)
      assert [%Event{} | _] = events
      assert hd(events).id == hd(@events_attrs)["id"]
    end

    test "returns a nil next_cursor on the last page" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"events" => @events_attrs})
      end)

      assert {:ok, %{next_cursor: nil}} = Gamma.list_events()
    end

    test "forwards query options to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert URI.decode_query(conn.query_string) == %{"limit" => "100", "closed" => "false"}
        Req.Test.json(conn, %{"events" => @events_attrs})
      end)

      assert {:ok, _} = Gamma.list_events(limit: 100, closed: false)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :list_events_failed} = Gamma.list_events()
    end

    test "returns an error when the body is not a keyset response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :list_events_failed} = Gamma.list_events()
    end

    test "returns an error when an event in the payload is invalid" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"events" => [%{"id" => "1"}]})
      end)

      assert {:error, :list_events_failed} = Gamma.list_events()
    end
  end

  describe "stream_events/1" do
    test "follows next_cursor across pages and yields every event" do
      [page1, page2] = Enum.chunk_every(@events_attrs, ceil(length(@events_attrs) / 2))

      Req.Test.stub(Polymarket.Gamma, fn conn ->
        case URI.decode_query(conn.query_string)["after_cursor"] do
          nil -> Req.Test.json(conn, %{"events" => page1, "next_cursor" => "CURSOR2"})
          "CURSOR2" -> Req.Test.json(conn, %{"events" => page2})
        end
      end)

      events = Gamma.stream_events() |> Enum.to_list()

      assert length(events) == length(@events_attrs)
      assert Enum.all?(events, &match?(%Event{}, &1))
      assert Enum.map(events, & &1.id) == Enum.map(@events_attrs, & &1["id"])
    end

    test "is lazy: only fetches pages as they are consumed" do
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Agent.update(calls, &(&1 + 1))
        # Every page reports a next_cursor, so the stream would page forever if
        # fully enumerated; taking 1 must stop after a single request.
        Req.Test.json(conn, %{"events" => Enum.take(@events_attrs, 1), "next_cursor" => "MORE"})
      end)

      assert [%Event{}] = Gamma.stream_events() |> Enum.take(1)
      assert Agent.get(calls, & &1) == 1
    end

    test "raises when a page fails to fetch" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert_raise RuntimeError, ~r/stream_events failed/, fn ->
        Gamma.stream_events() |> Enum.to_list()
      end
    end
  end
end
