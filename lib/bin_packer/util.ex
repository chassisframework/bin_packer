defmodule BinPacker.Util do
  # def dup_check_by!(enum, func) do
  #   enum
  #   |> Enum.group_by(func)
  #   |> Map.values
  #   |> Enum.reject(& length(&1) == 1)
  #   |> case do
  #        [] ->
  #          :ok

  #        duplicates ->
  #          # TODO: turn into a proper error
  #          raise "duplicates detected: #{inspect duplicates}"
  #      end
  # end

  def sum_by(enum, func) do
    Enum.reduce(enum, 0, fn i, sum -> func.(i) + sum end)
  end

  def stream_from_list(list) when is_list(list) do
    Stream.resource(
      fn -> list end,
      fn
        [next | rest] ->
          {[next], rest}
        [] ->
          {:halt, []}
      end,
      fn _ -> :noop end
    )
  end

  def std_dev(samples) when is_list(samples) do
    num_samples = length(samples)
    avg = Enum.sum(samples) / num_samples

    variance =
      samples
      |> sum_by(fn s ->
        s - avg |> :math.pow(2)
      end)
      |> Kernel./(num_samples)

    :math.sqrt(variance)
  end

  defmacro detect_invalid_propositions(propositions, bin_packer, state) do
    if Mix.env == :dev do
      quote do
        Enum.map(unquote(propositions), fn prop ->
          if !valid_proposition?(unquote(bin_packer), prop, unquote(state)) do
            raise "invalid proposition #{inspect prop}"
          end
          prop
        end)
      end
    else
      propositions
    end
  end


  # def parallel_map(enum, func) do
  #   enum
  #   |> Enum.map(&Task.async(fn -> func.(&1) end))
  #   |> Enum.map(&Task.await(&1, :infinity))
  # end

  # def time(func) do
  #   {time, return} = :timer.tc func
  #   IO.inspect time
  #   return
  # end
end
