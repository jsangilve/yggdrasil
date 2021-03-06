defmodule Yggdrasil.Distributor.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Generator

  test "start and stop distributor" do
    assert {:ok, generator} = Generator.start_link()
    assert :ok = Generator.stop(generator)
  end

  test "generate distributor" do
    {:ok, generator} = Generator.start_link()
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    Backend.subscribe(channel)
    {:ok, _} = Generator.start_distributor(generator, channel)

    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    :ok = Generator.stop_distributor(channel)
    :ok = Generator.stop(generator)
    Backend.unsubscribe(channel)
  end

  test "generate distributor twice" do
    {:ok, generator} = Generator.start_link()
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    Backend.subscribe(channel)
    {:ok, distributor} = Generator.start_distributor(generator, channel)

    assert {:ok, {:already_connected, ^distributor}} =
      Generator.start_distributor(generator, channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    :ok = Generator.stop(generator)
    Backend.unsubscribe(channel)
  end
end
