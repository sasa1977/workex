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

  defmodule DelayWorker do
    use Workex

    def init(pid), do: pid

    def handle(messages, pid) do
      :timer.sleep(30)
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
    {:ok, server} = Workex.start(EchoWorker, self, collect: Workex.Callback.Stack)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([3,2])
  end

  test "unique" do
    {:ok, server} = Workex.start(EchoWorker, self, collect: Workex.Callback.Unique)

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

  test "ets unique" do
    {:ok, server} = Workex.start(EchoWorker, self, collect: Workex.Callback.EtsUnique)

    Workex.push(server, {:a, 1})
    Workex.push(server, {:a, 2})
    Workex.push(server, {:a, 3})
    Workex.push(server, {:b, 4})

    assert_receive([{:a, 1}])
    assert_receive([{:b, 4}, {:a, 3}])
  end

  test "priority" do
    {:ok, server} = Workex.start(EchoWorker, self, collect: Workex.Callback.Priority)

    Workex.push(server, {1, :a})
    Workex.push(server, {1, :b})
    Workex.push(server, {2, :c})
    Workex.push(server, {1, :d})
    Workex.push(server, {3, :e})

    assert_receive([{1, :a}])
    assert_receive([{3, :e}, {2, :c}, {1, :b}, {1, :d}])
  end

  defmodule StackOneByOne do
    use Workex.Callback

    def init, do: []
    def clear([_|t]), do: t
    def clear([]), do: []
    def transform([h|_]), do: h
  end

  test "custom collect" do
    {:ok, server} = Workex.start(EchoWorker, self, collect: StackOneByOne)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive(1)
    assert_receive(3)
    assert_receive(2)
  end

  test "multiple random" do
    {:ok, server} = Workex.start(DelayWorker, self, collect: Workex.Callback.Queue)

    messages = generate_messages
    Enum.each(messages, fn(msg) ->
      Workex.push(server, msg)
      :timer.sleep(10)
    end)

    assert List.flatten(Enum.reverse(flush_messages)) == messages
  end

  test "priority structure" do
    priority = Workex.Priority.new
    assert Workex.Priority.empty?(priority) == true

    priority = Workex.Priority.add(priority, 1, :one)
    assert Workex.Priority.empty?(priority) == false
    assert Workex.Priority.to_list(priority) == [:one]

    priority =
      priority
      |> Workex.Priority.add(2, :two)
      |> Workex.Priority.add(1, :three)
      |> Workex.Priority.add(3, :four)

    assert Workex.Priority.empty?(priority) == false
    assert Workex.Priority.to_list(priority) == [:four, :two, :one, :three]
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
end