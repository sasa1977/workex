# Workex

By default, consumer processes in Erlang/Elixir don't have much control over received messages. This is especially true for `GenServer` based processes, where messages are processed one by one.

The `Workex` library provides the control over message receiving by splitting the consumer in two processes: one which accepts messages, and another process which handles them. This approach can be useful in various scenarios:

- Sometimes, bulk processing can speed up consuming, and processing of `N` items at once is much faster than `N` times processing of a single item.
- A maximum queue limit must be set after which the consumer should refuse new request.
- There is a need to eliminate duplicates. An item that arrives in queue makes the previous item of the same kind obsolete.
- A consumer should rearrange incoming messages by some priority (e.g. newest first).


## An example

Let's see a simple demonstration. Suppose we have a function that does long processing of some data:

```elixir
defmodule Processor do
  def long_op(data) do
    :timer.sleep(100)
    IO.inspect data
    :ok
  end
end
```

Obviously, this function can run at most 10 times per second. However, the running time is mostly unrelated to the size of the input data. Thus, we can benefit if we do bulking of input messages.

In particular, when a message arrives, the consumer can do following:

1. An idle consumer can immediately consume the message.
2. A busy consumer can queue the message. When the current processing is done, the consumer will process all queued messages at once.

This allows the consumer to automatically adapt to the incoming load of messages by taking the larger chunks of consumed messages.

Here's how we can do this with `Workex`. First, make sure you have `Workex` set as dependency in `mix.exs`:

```elixir
def deps do
  [{:workex, "~> 0.6.0"}, ...]
end

def application do
  [applications: [:workex, ...], ...]
end
```

Now, you can define the consumer as the callback used by the `Workex` behaviour:

```elixir
defmodule Consumer do
  use Workex

  # Interface functions are invoked inside client processes

  def start_link do
    Workex.start_link(__MODULE__, nil)
  end

  def push(pid, item) do
    Workex.push(pid, item)
  end


  # Callback functions run in the worker process

  def init(_), do: {:ok, nil}

  def handle(data, state) do
    Processor.long_op(data)
    {:ok, state}
  end
end
```

The producer can now start the Workex process, and push some data:

```elixir
{:ok, pid} = Consumer.start_link
for i <- 1..100 do
  Consumer.push(pid, i)
  :timer.sleep(10)
end

[1]                                     # after 100 ms
[10, 9, 8, 7, 6, 5, 4, 3, 2]            # after 200 ms
[19, 18, 17, 16, 15, 14, 13, 12, 11]    # after 300 ms
...
```

As you can see from the output, the first message is consumed immediately. In the meantime, all subsequent messages are aggregated and handled as soon as the consumer becomes idle. This allowed us to process 20 items in 300 ms, even though the processor function (`Processor.long_op/1`) takes about 100 ms.

`Workex` is a behaviour that runs two generic processes: the `Workex` powered process, and the internal worker process. The `Workex` process is a facade that accepts incoming items. It is tightly coupled with the worker process. As soon as the worker process is done processing, it notifies the `Workex` process, which may in turn provide new data, if there is some. Otherwise, the consumer is considered to be idle until the next message arrives.

The worker process is a long running process. Callback functions are invoked in this process and can manage some state. This works roughly like with `GenServer`. The `init/1` callback returns the initial state, while `handle/2` returns the new state. In case of a crash, both worker, and `Workex` process terminate, and the incoming queue is lost. This is analogous to the behaviour of plain BEAM processes.


## Message aggregation

As can be seen from the previous example, messages are by default aggregated in the stack. All new messages are placed on top, and the worker receives the reverse list (newer items are first).

There are two other data aggregation strategies provided:

- A `Workex.Queue` reverses the data prior to handing it off to the worker. This preserves the ordering of input messages.
- A `Workex.Dict` assumes that messages are in form of `{key, value}`. New message overwrites the queued one with the same key. The worker receives an unordered list of `{key, value}` tuples.

To use an alternative aggregation, you can start the server with:

```elixir
Workex.start_link(MyModule, arg, aggregate: %Workex.Queue{})
```

You can also implement your own aggregation strategies. This amounts to developing a structure that implements the `Workex.Aggregate` protocol.


## Limiting buffer

By default, `Workex` doesn't impose a limit to the message queue size. However, in some cases, you may want to refuse accepting new items after the queue size exceeds some limit. This can be done by providing the `max_size` option:

```elixir
Workex.start_link(MyModule, arg, max_size: 10)
```

If we have 10 items queued, all subsequent items will not enter the queue. Of course, once all queued items are passed to the worker server, the queue is emptied and `Workex` process will accept new items.


## Synchronous push

`Workex.push/2` is a fire-and-forget operation, which means you have no idea about its outcome. If you need some stronger guarantees, you can use `Workex.push_ack/2` which returns `:ok` if the item is successfully queued, or an error if the item was not queued (for example if the buffer limit has been reached).

There is also the function `Workex.push_block/2` which blocks the client (but not the `Workex` process) until the item has been processed by the worker. This is mostly useful if there are many concurrent producers pushing to the consumer, and you want to apply some stronger back pressure.