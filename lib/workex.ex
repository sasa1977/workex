defmodule Workex do
  defstruct [
    :worker_pid,
    :aggregate,
    :worker_available,
    :max_size,
    :replace_oldest,
    pending_responses: HashSet.new,
    processing_responses: HashSet.new
  ]
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  use Behaviour

  @typep worker_state :: any
  @type options :: [{:aggregate, module} | {:max_size, pos_integer} | {:replace_oldest, boolean}]

  defcallback init(any) :: {:ok, worker_state} | {:stop, reason :: any}
  defcallback handle(Workex.Aggregate.value, worker_state) :: {:ok, worker_state} | {:stop, reason :: any}

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  alias Workex.Aggregate

  @spec start(module, arg :: any, options, GenServer.options) :: GenServer.on_start
  defstart start(callback, arg, opts \\ []), gen_server_opts: :runtime

  @spec start_link(module, arg :: any, options, GenServer.options) :: GenServer.on_start
  defstart start_link(callback, arg, opts \\ []), gen_server_opts: :runtime

  definit {callback, arg, opts} do
    Process.flag(:trap_exit, true)
    case (Workex.Worker.start_link(self, callback, arg)) do
      {:ok, worker_pid} ->
        %__MODULE__{
          aggregate: opts[:aggregate] || %Workex.Queue{},
          worker_pid: worker_pid,
          max_size: opts[:max_size] || :unbound,
          replace_oldest: opts[:replace_oldest] || false,
          worker_available: true
        }
        |> initial_state
      {:error, reason} -> {:stop, reason}
    end
  end

  @spec push(GenServer.server, message :: any) :: :ok
  defcast push(message), state: state do
    {_, state} = add_and_notify(state, message)
    new_state(state)
  end


  @spec push_ack(GenServer.server, any, non_neg_integer | :infinity) :: :ok | {:error, reason :: any}
  def push_ack(server, message, timeout \\ 5000) do
    GenServer.call(server, {:push_ack, message}, timeout)
  end

  defhandlecall push_ack(message), state: state do
    {response, state} = add_and_notify(state, message)
    set_and_reply(state, response)
  end


  @spec push_block(GenServer.server, any, non_neg_integer | :infinity) :: :ok | {:error, reason :: any}
  def push_block(server, message, timeout \\ 5000) do
    GenServer.call(server, {:push_block, message}, timeout)
  end

  defhandlecall push_block(message), state: state, from: from do
    {response, state} = add_and_notify(state, message, from)
    case response do
      :ok -> new_state(state)
      _ -> set_and_reply(state, response)
    end
  end

  defp add_and_notify(
    %__MODULE__{
      aggregate: aggregate,
      max_size: max_size,
      worker_available: worker_available,
      replace_oldest: replace_oldest
    } = state,
    message,
    from \\ nil
  ) do
    if (not worker_available) and Aggregate.size(aggregate) == max_size do
      if replace_oldest do
        aggregate
        |> Aggregate.remove_oldest
        |> Aggregate.add(message)
        |> handle_add(state, from)
      else
        {{:error, :max_capacity}, state}
      end
    else
      aggregate
      |> Aggregate.add(message)
      |> handle_add(state, from)
    end
  end

  defp handle_add(add_result, state, from) do
    case add_result do
      {:ok, new_aggregate} ->
        {:ok,
          %__MODULE__{state | aggregate: new_aggregate}
          |> add_pending_response(from)
          |> maybe_notify_worker
        }
      error ->
        {error, state}
    end
  end

  defp add_pending_response(state, nil), do: state
  defp add_pending_response(%__MODULE__{pending_responses: pending_responses} = state, from) do
    %__MODULE__{state | pending_responses: HashSet.put(pending_responses, from)}
  end


  defp maybe_notify_worker(
    %__MODULE__{
      worker_available: true,
      worker_pid: worker_pid,
      aggregate: aggregate,
      pending_responses: pending_responses
    } = state
  ) do
    unless Aggregate.size(aggregate) == 0 do
      {payload, aggregate} = Aggregate.value(aggregate)
      Workex.Worker.process(worker_pid, payload)
      %__MODULE__{state |
        worker_available: false,
        aggregate: aggregate,
        processing_responses: pending_responses,
        pending_responses: HashSet.new
      }
    else
      state
    end
  end

  defp maybe_notify_worker(state), do: state


  defhandleinfo {:workex, :worker_available}, state: state do
    %__MODULE__{state | worker_available: true}
    |> notify_pending
    |> maybe_notify_worker
    |> new_state
  end

  defp notify_pending(%__MODULE__{processing_responses: processing_responses} = state) do
    Enum.each(processing_responses, &GenServer.reply(&1, :ok))
    %__MODULE__{state | processing_responses: HashSet.new}
  end


  defhandleinfo {:EXIT, worker_pid, reason}, state: %__MODULE__{worker_pid: worker_pid} do
    stop_server(reason)
  end

  defhandleinfo _, do: noreply
end