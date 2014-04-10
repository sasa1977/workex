defmodule Workex do
  @moduledoc """
    Workex structure which is used as a facade to multiple worker processes.
    See readme for detailed description
  """

  alias Workex.Worker.Queue, as: Queue

  defstruct [:supervisor, {:workers, HashDict.new}]


  def new(spec) do
    Enum.reduce(
      spec[:workers],
      %__MODULE__{supervisor: init_supervisor(spec[:supervisor])},
      &add_worker(&2, &1)
    )
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

  defp add_worker(
    %__MODULE__{supervisor: supervisor} = workex,
    worker_args
  ) do
    store_worker(workex,
      Workex.Worker.Queue.new([{:supervisor, supervisor} | worker_args])
    )
  end

  defp store_worker(%__MODULE__{workers: workers} = workex, worker) do
    %__MODULE__{workex | workers: Dict.put(workers, Queue.id(worker), worker)}
  end

  def push(%__MODULE__{workers: workers} = workex, worker_id, message) do
    store_worker(workex, Queue.push(workers[worker_id], message))
  end

  def handle_message(
    %__MODULE__{workers: workers} = workex,
    {:worker_available, worker_id}
  ) do
    store_worker(workex, Queue.worker_available(workers[worker_id], true))
  end

  def handle_message(
    %__MODULE__{workers: workers} = workex,
    {:worker_created, worker_id, worker_pid}
  ) do
    store_worker(workex,
      workers[worker_id]
      |> Queue.worker_pid(worker_pid)
      |> Queue.worker_available(true)
    )
  end
end