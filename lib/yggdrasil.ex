defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` manages subscriptions to channels/queues in several brokers with
  the possibility to add more. Simple Redis, RabbitMQ and PostgreSQL adapters
  are implemented. Message passing is done through `Phoenix.PubSub` adapters.

  `Yggdrasil` also manages publishing pools to Redis, RabbitMQ and PostgreSQL
  using `:poolboy` library.

  This library provides three functions

    * For clients: `Yggdrasil.subscribe/1` and `Yggdrasil.unsubscribe/1`.
    * For servers: `Yggdrasil.publish/2`.

  # Small Example

  The following example uses the Elixir distribution to send the messages. It
  is equivalent to the Redis, RabbitMQ and Postgres distributions when a
  connection configuration is supplied:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> channel = %Channel{name: "elixir_channel"}
  iex(3)> Yggdrasil.subscribe(channel)
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "elixir_channel", (...)}}
  ```

  and to publish a for the subscribers:

  ```elixir
  iex(5)> Yggdrasil.publish(channel, "message")
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "elixir_channel", (...)}, "message"}
  ```

  # Channel Structure

  The channels can be defined with the structure `Yggdrasil.Channel`, i.e:

  ```elixir
  channel = %Yggdrasil.Channel{
    name: "redis_channel",
    transformer: Yggdrasil.Transformer.Default,
    adapter: Yggdrasil.Subscriber.Adapter.Redis,
    namespace: TestRedis
  }
  ```

  where `name` is the name of the channel understood by the adapter. In this
  case the `adapter` used is `Yggdrasil.Subscriber.Adapter.Redis` that
  provides a basic fault tolerant subscription to Redis channel
  `"redis_channel"`, so the channel should be a string. Also for that reason
  this channel would be used only by subscribers so the `transformer` module
  should have the function `decode/2` to decode the messages coming from Redis
  to the subscribers. The default `transformer` module does nothing to the
  incoming message, so it should be a string. If no `transformer` is supplied,
  then it's used the default `transformer` `Yggdrasil.Default.Transformer`.
  The `namespace` tells `Yggdrasil` which adapter configuration should be used,
  i.e:

  ```elixir
  use Mix.Config

  config :yggdrasil, TestRedis,
    redis: [host: "localhost"]
  ```

  this allows you to have several connection configurations for the same
  broker. By default, the `namespace` is `Yggdrasil` if no `namespace` is
  supplied.

  The provided subscription adapters are the following (all are equivalents):

    * For `Elixir`: `Yggdrasil.Subscriber.Adapter.Elixir` and
    `Yggdrasil.Distributor.Adapter.Elixir`.
    * For `Redis`: `Yggdrasil.Subscriber.Adapter.Redis` and
    `Yggdrasil.Distributor.Adapter.Redis`.
    * For `RabbitMQ`: `Yggdrasil.Subscriber.Adapter.RabbitMQ` and
    `Yggdrasil.Distributor.Adapter.RabbitMQ`.
    * For `Postgres`: `Yggdrasil.Subscriber.Adapter.Postgres` and
    `Yggdrasil.Distributor.Adapter.Postgres`.

  The provided publisher adapters are the following:

    * For `Elixir`: `Yggdrasil.Publisherer.Adapter.Elixir`.
    * For `Redis`: `Yggdrasil.Publisher.Adapter.Redis`.
    * For `RabbitMQ`: `Yggdrasil.Publisher.Adapter.RabbitMQ`.
    * For `Postgres`: `Yggdrasil.Publisher.Adapter.Postgres`.

  Also there is possible to use hibrid adapters. They work both subscriptions
  and publishing (recommended):

    * For `Elixir`: `:elixir` and `Yggdrasil.Elixir`.
    * For `Redis`: `:redis` and `Yggdrasil.Redis`.
    * For `RabbitMQ`: `:rabbitmq` and `Yggdrasil.RabbitMQ`.
    * For `Postgres`: `:postgres` and `Yggdrasil.Postgres`.

  The format for the channels for every adapter is the following:

    * For `Elixir` adapter: any valid term.
    * For `Redis` adapter: a string.
    * For `RabbitMQ` adapter: a tuple with exchange and routing key.
    * For `Postgres` adapter: a string.

  # Custom Transformers

  It's possible to define custom transformers to _decode_ and _encode_ messages
  _from_ and _to_ the brokers respectively i.e:

  ```elixir
  iex(1)> defmodule QuoteTransformer do
  ...(1)>   use Yggdrasil.Transformer
  ...(1)>
  ...(1)>   alias Yggdrasil.Channel
  ...(1)>
  ...(1)>   def decode(%Channel{} = _channel, message) do
  ...(1)>     with {:ok, quoted} <- Code.string_to_quoted(message),
  ...(1)>          {encoded, _} <- Code.eval_quoted(quoted),
  ...(1)>          do: {:ok, encoded}
  ...(1)>     end
  ...(1)>
  ...(1)>   def encode(%Channel{} = _channel, data) do
  ...(1)>     encoded = inspect(data)
  ...(1)>     {:ok, encoded}
  ...(1)>   end
  ...(1)> end
  ```

  and using the RabbitMQ adapter the subscription channel would be:

  ```elixir
  iex(2)> sub_chan = %Yggdrasil.Channel{
  ...(2)>   name: {"amq.topic", "quotes"},
  ...(2)>   adapter: :rabbitmq,
  ...(2)>   transformer: QuoteTransformer
  ...(2)> }
  ```
  where the `name` of the channel for this adapter is a tuple with the
  exchange name and the routing key and the configuration doesn't have a
  namespace i.e:

  ```elixir
  use Mix.Config

  config :yggdrasil,
    rabbitmq: [host: "localhost"]
  ```

  and the publication channel would be:

  ```elixir
  iex(3)> pub_chan = %Yggdrasil.Channel{
  ...(3)>   name: {"amq.topic", "quotes"},
  ...(3)>   adapter: :rabbitmq,
  ...(3)>   transformer: QuoteTransformer
  ...(3)> }
  ```

  then:

  ```elixir
  iex(4)> Yggdrasil.subscribe(sub_chan)
  :ok
  iex(5)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{} = _channel}
  iex(6)> Yggdrasil.publish(pub_chan, %{"answer" => 42})
  :ok
  iex(7)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{} = _channel, %{"answer" => 42}}
  ```

  The only available transformer module is `Yggdrasil.Transformer.Default` and
  does nothing to the messages.

  # Configuration

  There are several configuration options and all of them should be in the
  general configuration for `Yggdrasil`:

    * `pubsub_adapter` - `Phoenix.PubSub` adapter. By default
    `Phoenix.PubSub.PG2` is used.
    * `pubsub_name` - Name of the `Phoenix.PubSub` adapter. By default is
    `Yggdrasil.PubSub`.
    * `pubsub_options` - Options of the `Phoenix.PubSub` adapter. By default
    are `[pool_size: 1]`.
    * `publisher_options` - `Poolboy` options for publishing. By default are
    `[size: 5, max_overflow: 10]`.
    * `registry` - Process name registry. By default is used `ExReg`.
    * `subscriber_options` - `Poolboy` options for RabbitMQ subscriber. By
    default are `[size: 5, max_overflow: 10]`.

  Also it can be specified the connection configurations with or without
  namespace:

    * `redis` - List of options of `Redix`:
      + `host` - Redis hostname.
      + `port` - Redis port.
      + `password` - Redis password.
    * `rabbitmq` - List of options of `AMQP`:
      + `host` - RabbitMQ hostname.
      + `port` - RabbitMQ port.
      + `username` - Username.
      + `password` - Password.
      + `virtual_host` - Virtual host.
    * `postgres` - List of options of `Postgrex`:
      + `hostname` - Postgres hostname.
      + `port` - Postgres port.
      + `username` - Postgres username.
      + `password` - Postgres password.
      + `database` - Postgres database name.
  """
  use Application
  use VersionCheck, application: :yggdrasil

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Publisher

  @publisher_gen Yggdrasil.Publisher.Generator
  @distributor_gen Yggdrasil.Distributor.Generator
  @rabbitmq_gen Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator
  @broker Yggdrasil.Broker

  ######################
  # Subscriber functions

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(%Channel{} = channel) do
    channel = transform_channel(:client, channel)
    with :ok <- Backend.subscribe(channel),
         do: @broker.subscribe(@broker, channel, self())
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(%Channel{} = channel) do
    channel = transform_channel(:client, channel)
    with :ok <- Backend.unsubscribe(channel),
         do: @broker.unsubscribe(@broker, channel, self())
  end

  #####################
  # Publisher functions

  @doc """
  Publishes a `message` in a `channel`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  def publish(%Channel{} = channel, message) do
    channel = transform_channel(:server, channel)
    with {:ok, _} <- @publisher_gen.start_publisher(@publisher_gen, channel),
         do: Publisher.publish(channel, message)
  end

  #########
  # Helpers

  @doc false
  def transform_channel(:server, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Elixir}
  end
  def transform_channel(:server, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Redis}
  end
  def transform_channel(:server, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.RabbitMQ}
  end
  def transform_channel(:server, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Postgres}
  end
  def transform_channel(:client, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Elixir}
  end
  def transform_channel(:client, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Redis}
  end
  def transform_channel(:client, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ}
  end
  def transform_channel(:client, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Postgres}
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Elixir} = channel) do
    transform_channel(type, %Channel{channel | adapter: :elixir})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Redis} = channel) do
    transform_channel(type, %Channel{channel | adapter: :redis})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.RabbitMQ} = channel) do
    transform_channel(type, %Channel{channel | adapter: :rabbitmq})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Postgres} = channel) do
    transform_channel(type, %Channel{channel | adapter: :postgres})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Elixir} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :elixir})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Redis} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :redis})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.RabbitMQ} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :rabbitmq})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Postgres} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :postgres})
  end
  def transform_channel(_, %Channel{} = channel) do
    channel
  end

  ###################
  # Application start

  @adapter Application.get_env(:yggdrasil, :pubsub_adapter, Phoenix.PubSub.PG2)
  @name Application.get_env(:yggdrasil, :pubsub_name, Yggdrasil.PubSub)
  @options Application.get_env(:yggdrasil, :pubsub_options, [pool_size: 1])

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    check_version()

    monitors = :ets.new(:monitors, [:set, :public, write_concurrency: false,
                                    read_concurrency: true])

    children = [
      supervisor(@adapter, [@name, @options]),
      supervisor(@rabbitmq_gen, [[name: @rabbitmq_gen]]),
      supervisor(@publisher_gen, [[name: @publisher_gen]]),
      supervisor(@distributor_gen, [[name: @distributor_gen]]),
      worker(@broker, [@distributor_gen, monitors, [name: @broker]])
    ]

    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
