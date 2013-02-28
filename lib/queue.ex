defrecord Workex.Worker.Queue, 
  [
    :id, :worker_pid, :messages, {:behaviour, Workex.Behaviour.Queue}, {:worker_available, true}
  ] do

  import Workex.RecordHelper
    
  defoverridable [new: 1]
  def new(data) do
    super(worker_args(data)) |>
    init_messages |>
    start_worker(job_args(data))
  end
  
  defp worker_args(data) do
    Enum.filter(data, fn({key, _}) -> key in [:id, :behaviour] end)
  end
  
  defp job_args(data) do
    Enum.filter(data, fn({key, _}) -> key in [:supervisor, :job, :state] end) |>
    adjust_job(data[:throttle])
  end

  defp adjust_job(data, nil), do: data
  defp adjust_job(data, throttle_time) do
    Keyword.put(data, :job, fn(messages, state) ->
      Workex.Throttler.throttle(throttle_time, fn() -> data[:job].(messages, state) end)
    end)
  end
  
  defp start_worker(this([id]), worker_args) do
    worker_args = [id: id, queue_pid: self] ++ worker_args

    {:ok, worker_pid} = case worker_args[:supervisor] do
      nil -> Workex.Worker.start_link(worker_args)
      pid -> :supervisor.start_child(pid, [worker_args])
    end
    this.worker_pid(worker_pid)
  end
  
  defp maybe_notify_worker(this([{:worker_available, true}, worker_pid])) do
    unless empty?(this) do
      Workex.Worker.process(worker_pid, transform_messages(this))
      worker_available(false, this) |>
      clear_messages
    else
      this
    end
  end
  
  defp maybe_notify_worker(this), do: this
  
  defoverridable [worker_available: 2]
  def worker_available(value, this([])) do
    this = super(value, this)
    maybe_notify_worker(this)
  end
  
  def push(message, this([behaviour, messages])) do
    behaviour.add(messages, message) |>
    messages(this) |>
    maybe_notify_worker
  end
  
  defp init_messages(this([behaviour])), do: this.messages(behaviour.init)
  defp clear_messages(this([messages, behaviour])) do
    behaviour.clear(messages) |>
    messages(this)
  end
  
  defp transform_messages(fields([behaviour, messages])) do
    behaviour.transform(messages)
  end

  defp empty?(fields([behaviour, messages])) do
    behaviour.empty?(messages)
  end
end