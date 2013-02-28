defrecord Workex, [:supervisor, {:workers, HashDict.new}] do
  @moduledoc """
    Workex structure which is used as a facade to multiple worker processes. 
    See readme for detailed description
  """

  import Workex.RecordHelper

  defoverridable [new: 1]
  def new(spec) do
    spec = Keyword.put(spec, :supervisor, init_supervisor(spec[:supervisor]))
    
    List.foldl(spec[:workers], super(Keyword.delete(spec, :workers)), function(:add_worker, 2))
  end
  
  defp init_supervisor(list) when is_list(list) do
    {:ok, pid} = :supervisor.start_link(Workex.Worker.Supervisor, list)
    pid
  end

  defp init_supervisor(nil), do: nil
  
  defp init_supervisor(pid) when is_pid(pid) or is_atom(pid) do
    Process.link(pid)
    pid
  end
  
  def add_worker(worker_args, this(supervisor)) do
    store_worker(Workex.Worker.Queue.new([{:supervisor, supervisor} | worker_args]), this)
  end
  
  defp store_worker(worker, this(workers)) do
    this.workers(Dict.put(workers, worker.id, worker))
  end
  
  def push(worker_id, message, this(workers)) do
    workers[worker_id].push(message) |>
    store_worker(this)
  end
  
  def handle_message({:worker_available, worker_id}, this(workers)) do
    workers[worker_id].worker_available(true) |>
    store_worker(this)
  end

  def handle_message({:worker_created, worker_id, worker_pid}, this(workers)) do
    workers[worker_id].worker_pid(worker_pid).worker_available(true) |>
    store_worker(this)
  end
end