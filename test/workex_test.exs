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

    def init(pid), do: pid

    def handle(messages, pid) do
      send(pid, messages)
      pid
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

  test "unique" do
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
      %__MODULE__{stack | items: [message | items]}
    end

    def value(%__MODULE__{items: [head | rest]} = stack), do: {head, %__MODULE__{stack | items: rest}}

    def empty?(%__MODULE__{items: []}), do: true
    def empty?(%__MODULE__{items: _}), do: false

    defimpl Workex.Aggregate do
      defdelegate add(data, message), to: StackOneByOne
      defdelegate value(data), to: StackOneByOne
      defdelegate empty?(data), to: StackOneByOne
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

  defp generate_messages do
    for _ <- (1..50 + :random.uniform(50)) do
      :random.uniform(10)
    end
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

    def init(pid), do: pid

    def handle(messages, pid) do
      :timer.sleep(30)
      send(pid, messages)
      pid
    end
  end

  test "multiple random" do
    {:ok, server} = Workex.start(DelayWorker, self, aggregate: %Workex.Queue{})

    messages = generate_messages
    Enum.each(messages, fn(msg) ->
      Workex.push(server, msg)
      :timer.sleep(10)
    end)

    assert List.flatten(Enum.reverse(flush_messages)) == messages
  end
end