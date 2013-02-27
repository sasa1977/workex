defmodule Workex.Throttler do
  def exec_and_measure(fun) do
    {time, result} = :timer.tc(fun)
    {round(time / 1000) + 1, result}
  end

  def throttle(time, fun) do
    {exec_time, result} = exec_and_measure(fun)
    do_throttle(time, exec_time)
    result
  end

  defp do_throttle(time, exec_time) when exec_time < time do
    :timer.sleep(time - exec_time)
  end

  defp do_throttle(_, _), do: :ok
end