defmodule BinPacker.BallsProportionalToBinObjective do
  @moduledoc """
  This objective attempts to place balls into bins such that the sum of the balls' usages is closest to
  the proportion of total capacity represented by the bin.

  For example, in a cluster of computers, a machine with 25% of the total cluster cpu capacity should be
  assigned 25% of the cpu "usage".
  """

  import BinPacker.Util, only: [sum_by: 2]

  alias BinPacker, as: BinPacker
  alias BinPacker.Assignments
  alias BinPacker.Bin
  alias BinPacker.Ball
  alias BinPacker.MoveProposition
  alias BinPacker.SwapProposition

  defmodule State do
    @moduledoc false

    defstruct [
      :ball_attribute_name,
      :bin_attribute_name,
      capacity_fractions: Map.new(),
      total_usage: 0,
      total_capacity: 0,
      cache: Map.new()
    ]
  end

  @behaviour BinPacker.Objective

  @impl true
  def init(args) do
    ball_attribute_name = Keyword.fetch!(args, :ball_attribute)
    bin_attribute_name = Keyword.fetch!(args, :bin_attribute)

    %State{ball_attribute_name: ball_attribute_name, bin_attribute_name: bin_attribute_name}
  end

  @impl true
  def proposition_executed(
    bin_packer,
    %MoveProposition{from_bin_id: from_bin_id, to_bin_id: to_bin_id},
    state
  ) do
    state
    |> update_cache(bin_packer, from_bin_id)
    |> update_cache(bin_packer, to_bin_id)
  end

  def proposition_executed(
    bin_packer,
    %SwapProposition{bin_id: bin_id, other_bin_id: other_bin_id},
    state
  ) do
    state
    |> update_cache(bin_packer, bin_id)
    |> update_cache(bin_packer, other_bin_id)
  end

  @impl true
  def bin_added(%BinPacker{assignments: %Assignments{bins: bins}} = bin_packer, bin, %State{bin_attribute_name: bin_attribute_name, total_capacity: total_capacity} = state) do
    total_capacity = total_capacity + Bin.attribute(bin, bin_attribute_name)

    capacity_fractions =
      Enum.into(bins, %{}, fn {id, bin} ->
        {id, Bin.attribute(bin, bin_attribute_name) / total_capacity}
      end)

    %State{state | total_capacity: total_capacity, capacity_fractions: capacity_fractions}
    |> bust_cache(bin_packer)
  end

  @impl true
  def ball_added(bin_packer, ball, %State{total_usage: total_usage, ball_attribute_name: ball_attribute_name} = state) do
    %State{state | total_usage: total_usage + Ball.attribute(ball, ball_attribute_name)}
    |> bust_cache(bin_packer)
  end

  @impl true
  def cost(_bin_packer, %State{cache: cache}) do
    sum_by(cache, fn {_bin_id, cost} -> cost end)
  end

  def cost_no_cache(bin_packer, state) do
    bin_packer
    |> Assignments.bin_ids()
    |> sum_by(fn bin_id -> bin_cost(bin_packer, bin_id, state) end)
  end

  defp bin_cost(
    _bin_packer,
    bin_id,
    %State{
      total_usage: 0,
      capacity_fractions: capacity_fractions}
  ) do
    Map.get(capacity_fractions, bin_id)
  end

  defp bin_cost(
    bin_packer,
    bin_id,
    %State{
      ball_attribute_name: ball_attribute_name,
      total_usage: total_usage,
      capacity_fractions: capacity_fractions}
  ) do
    bin_usage =
      bin_packer
      |> Assignments.balls_for_bin_id(bin_id)
      |> sum_by(&Ball.attribute(&1, ball_attribute_name))

    usage_fraction = bin_usage / total_usage
    capacity_fraction = Map.get(capacity_fractions, bin_id)

    abs(usage_fraction - capacity_fraction)
  end

  defp update_cache(%State{cache: cache} = state, bin_packer, bin_id) do
    cost = bin_cost(bin_packer, bin_id, state)

    %State{state | cache: Map.put(cache, bin_id, cost)}
  end

  #
  # adding a single bin or ball causes capacity fractions or total usage to change, respectively,
  # so we have to bust and recompute the entire cache
  #
  defp bust_cache(%State{} = state, bin_packer) do
    cache =
      bin_packer
      |> Assignments.bin_ids()
      |> Enum.into(%{}, fn bin_id -> {bin_id, bin_cost(bin_packer, bin_id, state)} end)

    %State{state | cache: cache}
  end
end
