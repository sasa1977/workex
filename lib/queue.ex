defrecord Workex.Worker.Queue, 
  [
    :id, :worker_pid, :messages, {:behaviour, Workex.Behaviour.Queue}, {:worker_available, true}
  ] do
    
  defoverridable [new: 1]
  def new(data) do
    super(worker_args(data)).
      init_messages.
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
  
  def start_worker(worker_args, this) do
    worker_args = [id: this.id, queue_pid: self] ++ worker_args

    {:ok, worker_pid} = case worker_args[:supervisor] do
      nil -> Workex.Worker.start_link(worker_args)
      pid -> :supervisor.start_child(pid, [worker_args])
    end
    this.worker_pid(worker_pid)
  end
  
  def notify_worker(Workex.Worker.Queue[worker_available: true] = this) do
    unless this.empty? do
      this.worker_pid <- {:workex, :new_data, this.transform_messages}
      this.worker_available(false).clear_messages
    else
      this
    end
  end
  
  def notify_worker(this), do: this
  
  defoverridable [worker_available: 2]
  def worker_available(value, this) do
    this = super(value, this)
    if this.worker_available do
      this.notify_worker
    else
      this
    end
  end
  
  def push(message, this) do
    this.
      update_messages(this.behaviour.add(&1, message)).
      notify_worker
  end
  
  def clear_messages(this), do: this.update_messages(fn(messages) -> this.behaviour.clear(messages) end)
  def init_messages(this), do: this.messages(this.behaviour.init)
  
  defoverridable [messages: 1]
  def transform_messages(this), do: this.behaviour.transform(this.messages)

  def empty?(this), do: this.behaviour.empty?(this.messages)
end