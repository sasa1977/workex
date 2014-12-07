defmodule WorkexTest do
  use ExUnit.Case

  setup do
    flush_messages
    :random.seed(:erlang.now)
    :ok
  end

  defp flush_messages(acc \\ []) do
    receive do
      x -> flush_messages([x | acc])
    after 50 ->
      acc
    end
  end

  defmodule EchoWorker do
    use Workex

    def init({:stop, reason}), do: {:stop, reason}
    def init(pid), do: {:ok, pid}

    def handle([{:stop, reason}], _) do
      {:stop, reason}
    end

    def handle([{:raise, error}], _) do
      :erlang.error(error)
    end

    def handle([{:delay, delay, message}], pid) do
      :timer.sleep(delay)
      handle([message], pid)
    end

    def handle(messages, pid) do
      send(pid, messages)
      {:ok, pid}
    end
  end

  test "default" do
    {:ok, server} = Workex.start(EchoWorker, self)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([3,2])
  end

  test "sync default" do
    {:ok, server} = Workex.start(EchoWorker, self)

    assert :ok == Workex.push_ack(server, 1)
    assert :ok == Workex.push_ack(server, 2)
    assert :ok == Workex.push_ack(server, 3)

    assert_receive([1])
    assert_receive([2])
    assert_receive([3])
  end

  test "shedding" do
    {:ok, server} = Workex.start(EchoWorker, self, max_size: 1)

    assert :ok == Workex.push_ack(server, {:delay, 100, 1})
    assert :ok == Workex.push_ack(server, 2)
    assert {:error, :max_capacity} == Workex.push_ack(server, 3)

    assert_receive([1], 500)
    assert_receive([2])
    assert :ok == Workex.push_ack(server, 3)
    assert_receive([3])
  end

  test "stack" do
    {:ok, server} = Workex.start(EchoWorker, self, aggregate: %Workex.Stack{})

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([3,2])
  end

  test "queue" do
    {:ok, server} = Workex.start(EchoWorker, self, aggregate: %Workex.Queue{})

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([2, 3])
  end

  test "dict" do
    {:ok, server} = Workex.start(EchoWorker, self, aggregate: %Workex.Dict{})

    Workex.push(server, {:a, 1})
    Workex.push(server, {:a, 2})
    Workex.push(server, {:a, 3})
    Workex.push(server, {:b, 4})

    assert_receive([{:a, 1}])

    message = receive do x -> x after 100 -> flunk end
    assert length(message) == 2
    assert message[:a] == 3
    assert message[:b] == 4
  end

  defmodule StackOneByOne do
    defstruct items: []

    def add(%__MODULE__{items: items} = stack, message) do
      {:ok, %__MODULE__{stack | items: [message | items]}}
    end

    def value(%__MODULE__{items: [head | rest]} = stack), do: {head, %__MODULE__{stack | items: rest}}

    def size(%__MODULE__{items: items}), do: length(items)

    defimpl Workex.Aggregate do
      defdelegate add(data, message), to: StackOneByOne
      defdelegate value(data), to: StackOneByOne
      defdelegate size(data), to: StackOneByOne
    end
  end

  test "custom collect" do
    {:ok, server} = Workex.start(EchoWorker, self, aggregate: %StackOneByOne{})

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive(1)
    assert_receive(3)
    assert_receive(2)
  end

  test "gen_server_opts" do
    {:ok, server} = Workex.start(EchoWorker, self, [], name: :foo)
    assert server == Process.whereis(:foo)
    assert {:error, {:already_started, server}} == Workex.start(EchoWorker, self, [], name: :foo)

    Workex.push(:foo, 1)
    Workex.push(:foo, 2)
    Workex.push(:foo, 3)

    assert_receive([1])
    assert_receive([3,2])
  end


  defmodule DelayWorker do
    use Workex

    def init(pid), do: {:ok, pid}

    def handle(messages, pid) do
      :timer.sleep(3)
      send(pid, messages)
      {:ok, pid}
    end
  end

  test "multiple random" do
    {:ok, server} = Workex.start(DelayWorker, self, aggregate: %Workex.Queue{})

    messages = for i <- (1..1000) do
      {i, :random.uniform(10)}
    end

    Enum.each(messages, fn({i, msg}) ->
      if rem(i, 100) == 0, do: :timer.sleep(10)
      Workex.push(server, msg)
    end)

    assert List.flatten(Enum.reverse(flush_messages)) == Enum.map(messages, &elem(&1, 1))
  end


  test "stop worker" do
    assert {:error, :stop_reason} == Workex.start(EchoWorker, {:stop, :stop_reason})

    Process.flag(:trap_exit, true)
    try do
      Logger.remove_backend(:console)
      {:ok, server} = Workex.start_link(EchoWorker, self, [])
      Workex.push(server, {:stop, :stop_reason})
      assert_receive({:EXIT, ^server, :stop_reason})
    after
      Process.flag(:trap_exit, false)
    end
  end

  test "error propagation" do
    Process.flag(:trap_exit, true)
    try do
      Logger.remove_backend(:console)
      {:ok, server} = Workex.start_link(EchoWorker, self)
      Workex.push(server, {:raise, "an error"})
      assert_receive({:EXIT, ^server, {"an error", _}})
    after
      Process.flag(:trap_exit, false)
    end
  end
end