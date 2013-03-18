# Workex

Normally, worker processes in Erlang/Elixir don't have much control over the received messages. This is especially true for the gen_server based processes, which process messages one by one, as they are received.

The Workex library provides the control over message receiving by splitting the worker in two processes: one which accepts messages, and the other which processes them.

The primary use case is the accumulation of the messages which are received while the worker is processing the current request. This makes it possible to handle all accumulated messages at once.

Another feature is the option to control how the messages are accumulated, which allows message rearranging (for example to eliminate duplicates, or to handle the new messages first) and discarding.

## Workex server

This is the simplest usage form, where you start a server which is a wrapper around multiple workers. A worker is a function running in its own process and consuming messages. A message can be any erlang term.

General rules:
  1. If the receiving worker is idle, it will immediately get the message.
  2. While the worker is busy, all incoming messages are accumulated. As soon as it becomes idle, it will receive all the new messages.
  3. Messages are sent as lists, in the order received by the server process.
  4. Message sending is a cast (async) operation.

Example:

```elixir
{:ok, workex_pid} = Workex.Server.start_link([workers: [
  [id: :my_worker, job: fn(message, _) -> ... end]
]])

Workex.Server.push(workex_pid, :my_worker, :msg1)
Workex.Server.push(workex_pid, :my_worker, :msg2)
Workex.Server.push(workex_pid, :my_worker, :msg3)
```
    
Here, the worker will receive two messages with values `[:msg1]` and then `[:msg2, :msg3]`.

## Process structure

Both the workex server process and the worker processes are implemented as gen_servers. The workers are linked to the workex server, so a crash in one worker kills the entire structure.

It is possible to use a _simple\_one\_for\_one_ supervisor to start and supervise workers:

```elixir
# using workex supervisor
{:ok, server} = Workex.Server.start([supervisor: [restart: :permanent, shutdown: 5000], workers: [...]])

# using your own simple_one_for_one
{:ok, server} = Workex.Server.start([supervisor: pid, workers: [...]])
```
    
In the first approach, the workex creates (and links) its own supervisor with the arguments provided. In the second version, you provide a pid of the already created _simple\_one\_for\_one_ supervisor.  
When supervisor is used, worker processes are not linked to the workex server.

Notice that the workex server is not included in the supervision tree: it is up to you to do it. However, the server will be linked to the supervisor of worker processes (if you use one), so in case of its termination, it will also die.

## The worker state

Each worker maintains its own state. The initial state is provided in the worker spec. The current state is received as the second argument of the job function while the function's return value is used as the new state:

```elixir
{:ok, workex_pid} = Workex.Server.start_link([workers: [
  [id: :my_worker, state: 0, job: fn(_, cnt) -> cnt + 1 end]
]])
```

## Throttling

If desired, you can throttle the worker so it does not processes messages too often:

```elixir
Workex.Server.start_link([workers: [
  [id: :my_worker, throttle: 1000, ...]
]])
```

The call above ensures that the worker will not be invoked more often than every 1000 ms.

The throttling time incorporates the execution time of the worker. If the worker performs its task in less than 1000 ms, a sleep in its process will be invoked, assuring that it waits for the remaining time. However, if the processing time is larger, no sleep will take place, and if new messages are available, they will be processed immediately. If you want to ensure that worker waits for some fixed amount of time after it has done processing, add a _:timer.sleep_ call in the worker function.

## Message manipulation

By default the worker receives messages as the chronologically sorted list (older messages come first). Three alternative implementations are provided.

### Stack

Accumulates messages in the list, newer messages come first:

```elixir
{:ok, workex_pid} = Workex.Server.start_link([workers: [
  [id: :my_worker, behaviour: Workex.Behaviour.Stack, job: fn(message, _) -> ... end]
]])

Workex.Server.push(workex_pid, :my_worker, :msg1)
Workex.Server.push(workex_pid, :my_worker, :msg2)
Workex.Server.push(workex_pid, :my_worker, :msg3)
```
    
The worker will receive `[:msg1]` and then `[:msg3 ,:msg2]`.

### Unique

Unique assumes that messages are tuples and that the first element of the tuple is the message id. When accumulating messages, the new message overwrites the accumulated older one with the same id. The ordering is not preserved.

```elixir
{:ok, workex_pid} = Workex.Server.start_link([workers: [
  [id: :my_worker, behaviour: Workex.Behaviour.Unique, job: fn(message, _) -> ... end]
]])

Workex.Server.push(workex_pid, :my_worker, {:msg1, :a})
Workex.Server.push(workex_pid, :my_worker, {:msg2, :b})
Workex.Server.push(workex_pid, :my_worker, {:msg2, :c})
Workex.Server.push(workex_pid, :my_worker, {:msg3, :d})
```
    
The worker will receive `[{:msg1, :a}]` and then `[{:msg3, :d}, {:msg2, :c}]`

### Priority

Priority assumes that messages are tuples, and that the first element of the tuple is a number representing message priority. The accumulated messages are sorted by desending priority. If two messages have the same priority, they are sorted by the order received:

```elixir
{:ok, workex_pid} = Workex.Server.start_link([workers: [
  [id: :my_worker, behaviour: Workex.Behaviour.Priority, job: fn(message, _) -> ... end]
]])

Workex.Server.push(server, :my_worker, {1, :a})
Workex.Server.push(server, :my_worker, {1, :b})
Workex.Server.push(server, :my_worker, {2, :c})
Workex.Server.push(server, :my_worker, {1, :d})
Workex.Server.push(server, :my_worker, {3, :e})
```

The worker will receive `[{1, :a}]` and then `[{3, :e}, {2, :c}, {1, :b}, {1, :d}]`

### Custom

You can easily implement your own custom behaviour. This one stores messages in the lists, and sends them one by one, newer first.

```elixir
defmodule StackOneByOne do
  use Workex.Behaviour.Base

  def init, do: []
  
  def clear([_|t]), do: t
  def clear([]), do: []

  def add(messages, message), do: [message | messages]
  def transform([h|_]), do: h

  def empty?([]), do: true
  def empty?(_), do: false
end
```

Not all functions must be implemented. The default implementation is inherited from the base behaviour, which is the stack implementation. The compact version could look like this:

```elixir
defmodule StackOneByOne do
  use Workex.Behaviour.Base

  def clear([_|t]), do: t
  def clear([]), do: []
  def transform([h|_]), do: h
end
```

## Removing the server process

The workex server is an Erlang process. If for some reason you don't want to create this extra process, you can use the Workex module inside your own process. 

Create the workex structure in the owner process:

```elixir
workex = Workex.new(args)   # args follow the same rule as when creating the server
```

Then push messages:

```elixir
new_workex = workex.push(worker_id, message)
```

Finally, inside the owner process, you must handle the workex messages which will be sent by worker processes:

```elixir
receive do
  {:workex, workex_message} -> new_workex = workex.handle_message(workex_message)
end
```

Notice that calls to _push_ and _handle\_message_ return the modified workex structure which you must incorporate in your owner process state.  
See the implementation of the _Workex.Server_ for full details.

## Performance considerations

1. Each message is passed one extra time (from the workex server to the corresponding worker).
2. In the default queue implementation, new messages are appended at the top of the list. However, when sending to the worker process, this list of accumulated messages is reversed.
3. Message accumulation / rearranging takes place in workex server or the owner process of the workex structure.
