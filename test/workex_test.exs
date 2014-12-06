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

  test "workex server" do
    {:ok, server} = Workex.start(echo_worker)

    Workex.push(server, :foo)
    assert_receive([:foo])
  end

  test "default" do
    {:ok, server} = Workex.start(echo_worker)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([3,2])
  end

  test "stack" do
    {:ok, server} = Workex.start(Workex.Callback.Stack, echo_worker)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive([1])
    assert_receive([3,2])
  end

  test "unique" do
    {:ok, server} = Workex.start(Workex.Callback.Unique, echo_worker)

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
    {:ok, server} = Workex.start(Workex.Callback.EtsUnique, echo_worker)

    Workex.push(server, {:a, 1})
    Workex.push(server, {:a, 2})
    Workex.push(server, {:a, 3})
    Workex.push(server, {:b, 4})

    assert_receive([{:a, 1}])
    assert_receive([{:b, 4}, {:a, 3}])
  end

  test "priority" do
    {:ok, server} = Workex.start(Workex.Callback.Priority, echo_worker)

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

  test "custom callback" do
    {:ok, server} = Workex.start(StackOneByOne, echo_worker)

    Workex.push(server, 1)
    Workex.push(server, 2)
    Workex.push(server, 3)

    assert_receive(1)
    assert_receive(3)
    assert_receive(2)
  end

  test "multiple random" do
    {:ok, server} = Workex.start(Workex.Callback.Queue, delay_worker)

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

  defmacrop between(x, y, z) do
    quote do
      a = unquote(x)
      a > unquote(y) && a < unquote(z)
    end
  end

  test "throttler" do
    assert between(exec_throttle( 0),  30,  70)
    assert between(exec_throttle( 30), 30,  70)
    assert between(exec_throttle(100), 80, 120)
  end

  defp exec_throttle(sleep_time) do
    Workex.Throttler.exec_and_measure(fn() ->
      Workex.Throttler.throttle(50, fn() -> :timer.sleep(sleep_time) end)
    end) |>
    elem(0)
  end

  defp generate_messages do
    for _ <- (1..50 + :random.uniform(50)) do
      :random.uniform(10)
    end
  end

  defp echo_worker(args \\ []) do
    [job: fn(msg, pid) -> send(pid, msg); pid end, state: self] ++ args
  end

  defp delay_worker(args \\ []) do
    [job: fn(msg, pid) -> send(pid, msg); pid end, state: self, throttle: 30] ++ args
  end
end
