Code.require_file "../test_helper.exs", __FILE__

defmodule WorkexTest do
  use ExUnit.Case
  
  setup do
    flush_messages
    seed_random
    :ok
  end

  defp flush_messages(acc // []) do
    receive do
      x -> flush_messages([x | acc])
    after 50 ->
      acc
    end
  end
  
  test "workex worker" do
    workex_queue = Workex.Worker.Queue.new(echo_worker(:worker_id))
    assert workex_queue.worker_available == true
    
    workex_queue = workex_queue.push(1)
    assert workex_queue.worker_available == false
    assert_receive([1])
    assert_receive({:workex, {:worker_available, :worker_id}})
    assert_receive({:workex, {:worker_created, _, _}})
    
    workex_queue = workex_queue.push(2).push(3)
    refute_receive(_)
    
    workex_queue.worker_available(true)
    assert_receive([2,3])
    assert_receive({:workex, {:worker_available, :worker_id}})
    refute_receive(_)
  end

  test "workex" do
    workex = Workex.new([workers: [echo_worker(:worker_id)]])
    workex = workex.push(:worker_id, 1)
    assert_receive([1])
    
    get_and_handle_message(workex, 2)

    refute_receive(_)
  end
  
  test "multiple workex" do
    workex = Workex.new([workers: [echo_worker(:worker1), echo_worker(:worker2)]])
    workex.push(:worker1, 1).push(:worker2, 2)
    assert_receive([1])
    assert_receive([2])    
  end
  
  test "workex server" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker_id)]])
    
    Workex.Server.push(server, :worker_id, 1)
    assert_receive([1])
  end
  
  test "stack" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker_id, behaviour: Workex.Behaviour.Stack)]])
    
    Workex.Server.push(server, :worker_id, 1)
    Workex.Server.push(server, :worker_id, 2)
    Workex.Server.push(server, :worker_id, 3)
    
    assert_receive([1])
    assert_receive([3,2])
  end
  
  test "unique" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker_id, behaviour: Workex.Behaviour.Unique)]])
    
    Workex.Server.push(server, :worker_id, {:a, 1})
    Workex.Server.push(server, :worker_id, {:a, 2})
    Workex.Server.push(server, :worker_id, {:a, 3})
    Workex.Server.push(server, :worker_id, {:b, 4})
    
    assert_receive([{:a, 1}])
    assert_receive([{:b, 4}, {:a, 3}])
  end

  test "priority" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker_id, behaviour: Workex.Behaviour.Priority)]])
    
    Workex.Server.push(server, :worker_id, {1, :a})
    Workex.Server.push(server, :worker_id, {1, :b})
    Workex.Server.push(server, :worker_id, {2, :c})
    Workex.Server.push(server, :worker_id, {1, :d})
    Workex.Server.push(server, :worker_id, {3, :e})
    
    assert_receive([{1, :a}])
    assert_receive([{3, :e}, {2, :c}, {1, :b}, {1, :d}])
  end
  
  defmodule StackOneByOne do
    use Workex.Behaviour.Base
    
    def init, do: []
    def clear([_|t]), do: t
    def clear([]), do: []
    def transform([h|_]), do: h
  end
  
  test "custom behaviour" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker_id, behaviour: StackOneByOne)]])
    
    Workex.Server.push(server, :worker_id, 1)
    Workex.Server.push(server, :worker_id, 2)
    Workex.Server.push(server, :worker_id, 3)
    
    assert_receive(1)
    assert_receive(3)
    assert_receive(2)
  end
  
  test "supervisor server" do
    workex = Workex.new([
      supervisor: [restart: :permanent, shutdown: 5000],
      workers: [
        [
          id: :worker1, 
          state: self,
          job: 
            function do
              ([:crash], _) -> exit(:normal)
              (any, pid) -> 
                pid <- any
                pid
            end
        ],
        echo_worker(:worker2)
      ]
    ])

    workex = get_and_handle_message(workex, 2)
    original_workex = workex

    workex = workex.push(:worker2, 1).push(:worker1, :crash)
    assert_receive([1])
    workex = get_and_handle_message(workex, 2)

    assert workex.workers[:worker1].worker_pid != original_workex.workers[:worker1].worker_pid
    assert workex.workers[:worker2].worker_pid == original_workex.workers[:worker2].worker_pid
    
    workex.push(:worker1, 1)
    assert_receive([1])
  end

  test "multiple random" do
    {:ok, server} = Workex.Server.start([workers: [delay_worker(:worker_id)]])

    messages = generate_messages
    Enum.each(messages, fn(msg) -> 
      Workex.Server.push(server, :worker_id, msg)
      :timer.sleep(10)
    end)
    
    assert List.flatten(Enum.reverse(flush_messages)) == messages
  end

  test "priority structure" do
    priority = Workex.Priority.new
    assert priority.empty? == true

    priority = priority.add(1, :one)
    assert priority.empty? == false
    assert priority.to_list == [:one]

    priority = priority.
      add(2, :two).
      add(1, :three).
      add(3, :four)

    assert priority.empty? == false
    assert priority.to_list == [:four, :two, :one, :three]
  end

  defp seed_random do
    {a1,a2,a3} = :erlang.now
    :random.seed(a1,a2,a3)
  end

  defp generate_messages, do: generate_messages(50 + :random.uniform(50), [])
  defp generate_messages(0, acc), do: acc
  defp generate_messages(n, acc), do: generate_messages(n - 1, [:random.uniform(10) | acc])
  
  defp get_and_handle_message(workex, cnt) do
    List.foldl(:lists.seq(1, cnt), workex, fn(_, workex) ->
      {:workex, msg} = rcv
      workex.handle_message(msg)
    end)
  end

  defp echo_worker(worker_id, args // []) do
    [id: worker_id, job: fn(msg, pid) -> pid <- msg; pid end, state: self] ++ args
  end

  defp delay_worker(worker_id, args // []) do
    [id: worker_id, job: fn(msg, pid) -> :timer.sleep(30); pid <- msg; pid end, state: self] ++ args
  end
  
  defp rcv do
    receive do
      x -> x
    after 
      500 -> flunk("no message")
    end
  end
end
