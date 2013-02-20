defrecord Workex, [:supervisor, {:workers, HashDict.new}] do
  @moduledoc """
    Workex structure which is used as a facade to multiple worker processes. 
    See readme for detailed description
  """

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
  
  def add_worker(worker_args, this) do
    this.store_worker(Workex.Worker.Queue.new([{:supervisor, this.supervisor} | worker_args]))
  end
  
  def store_worker(worker, this) do
    this.update_workers(fn(workers) -> Dict.put(workers, worker.id, worker) end)
  end
  
  def push(worker_id, message, this) do
    this.workers[worker_id].push(message) |>
    this.store_worker
  end
  
  def handle_message({:worker_available, worker_id}, this) do
    this.workers[worker_id].worker_available(true) |>
    this.store_worker
  end

  def handle_message({:worker_created, worker_id, worker_pid}, this) do
    this.workers[worker_id].worker_pid(worker_pid).worker_available(true) |>
    this.store_worker
  end
end