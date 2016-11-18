defmodule Yggdrasil.Distributor.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher

  test "start, stop" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      transformer: Yggdrasil.Transformer.Default
    }

    {:ok, publisher} = Publisher.start_link(channel)
    Publisher.stop(publisher)
  end

  test "notify" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      transformer: Yggdrasil.Transformer.Default
    }
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)

    assert :ok = Publisher.notify(publisher, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}

    Backend.unsubscribe(channel)
    Publisher.stop(publisher)
  end
end