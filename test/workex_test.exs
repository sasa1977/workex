Code.require_file "../test_helper.exs", __FILE__

defmodule WorkexTest do
  use ExUnit.Case
  
  def setup do
    flush_messages
    seed_random
  end

  defp flush_messages(acc // []) do
    receive do
      x -> flush_messages([x | acc])
    after 50 ->
      acc
    end
  end
  
  test "workex worker" do
    workex_queue = Workex.Worker.Queue.new(echo_worker(:worker1))
    assert workex_queue.worker_available == true
    
    workex_queue = workex_queue.push(1)
    assert workex_queue.worker_available == false
    assert_receive([1])
    assert_receive({:workex, {:worker_available, :worker1}})
    assert_receive({:workex, {:worker_created, _, _}})
    
    workex_queue = workex_queue.push(2).push(3)
    refute_receive(_)
    
    workex_queue.worker_available(true)
    assert_receive([2,3])
    assert_receive({:workex, {:worker_available, :worker1}})
    refute_receive(_)
  end

  test "workex" do
    workex = Workex.new([workers: [echo_worker(:worker2)]])
    workex = workex.push(:worker2, 1)
    assert_receive([1])
    
    get_and_handle_message(workex, 2)

    refute_receive(_)
  end
  
  test "multiple workex" do
    workex = Workex.new([workers: [echo_worker(:worker3), echo_worker(:worker4)]])
    workex.push(:worker3, 1).push(:worker4, 2)
    assert_receive([1])
    assert_receive([2])    
  end
  
  test "workex server" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker5)]])
    
    Workex.Server.push(server, :worker5, 1)
    assert_receive([1])
  end
  
  test "stack" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker6, behaviour: Workex.Behaviour.Stack)]])
    
    Workex.Server.push(server, :worker6, 1)
    Workex.Server.push(server, :worker6, 2)
    Workex.Server.push(server, :worker6, 3)
    
    assert_receive([1])
    assert_receive([3,2])
  end
  
  test "unique" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker7, behaviour: Workex.Behaviour.Unique)]])
    
    Workex.Server.push(server, :worker7, {:a, 1})
    Workex.Server.push(server, :worker7, {:a, 2})
    Workex.Server.push(server, :worker7, {:a, 3})
    Workex.Server.push(server, :worker7, {:b, 4})
    
    assert_receive([{:a, 1}])
    assert_receive([{:b, 4}, {:a, 3}])
  end
  
  defmodule StackOneByOne do
    use Workex.Behaviour.Base
    
    def init, do: []
    def clear([_|t]), do: t
    def clear([]), do: []
    def transform([h|_]), do: h
  end
  
  test "custom behaviour" do
    {:ok, server} = Workex.Server.start([workers: [echo_worker(:worker8, behaviour: StackOneByOne)]])
    
    Workex.Server.push(server, :worker8, 1)
    Workex.Server.push(server, :worker8, 2)
    Workex.Server.push(server, :worker8, 3)
    
    assert_receive(1)
    assert_receive(3)
    assert_receive(2)
  end
  
  test "supervisor server" do
    workex = Workex.new([
      supervisor: [restart: :permanent, shutdown: 5000],
      workers: [
        [
          id: :worker10, 
          state: self,
          job: 
            function do
              ([:crash], _) -> exit(:normal)
              (any, pid) -> 
                pid <- any
                pid
            end
        ],
        echo_worker(:worker11)
      ]
    ])

    workex = get_and_handle_message(workex, 2)
    original_workex = workex

    workex = workex.push(:worker11, 1).push(:worker10, :crash)
    assert_receive([1])
    workex = get_and_handle_message(workex, 2)

    assert workex.workers[:worker10].worker_pid != original_workex.workers[:worker10].worker_pid
    assert workex.workers[:worker11].worker_pid == original_workex.workers[:worker11].worker_pid
    
    workex.push(:worker10, 1)
    assert_receive([1])
  end

  test "multiple random" do
    {:ok, server} = Workex.Server.start([workers: [delay_worker(:worker12)]])

    messages = generate_messages
    Enum.each(messages, fn(msg) -> 
      Workex.Server.push(server, :worker12, msg)
      :timer.sleep(10)
    end)
    
    assert List.flatten(Enum.reverse(flush_messages)) == messages
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
