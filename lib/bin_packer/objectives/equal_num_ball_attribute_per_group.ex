defmodule BinPacker.EqualNumBallAttributePerGroupObjective do
  @moduledoc """
  This objective attempts to place balls into bins such that the given ball attribute is equally represented in each group of bins sharing the same bin attribute.

  For example, in a cluster of computers, each housing many replicated data partitions, and one replica per partition is the "master",
  we'd use this objective to place an equal number of masters in each location.

  This objective is a relaxed verion of the OnePerGroupConstraint, instead of being a hard constraint, it's a soft objective measured
  using the deviation of the number of ball attributes per group: https://en.wikipedia.org/wiki/Standard_deviation
  """

  # TODO: implement cached version

  import BinPacker.Util, only: [std_dev: 1]

  alias BinPacker, as: BinPacker
  alias BinPacker.Assignments
  alias BinPacker.Bin
  alias BinPacker.Ball
  # alias BinPacker.MoveProposition
  # alias BinPacker.SwapProposition

  @behaviour BinPacker.Objective

  defmodule State do
    @moduledoc false

    defstruct [
      :ball_attribute,
      :bin_attribute,
      # cache: Map.new()
    ]
  end

  @impl true
  def init(args) do
    ball_attribute = Keyword.fetch!(args, :ball_attribute)
    bin_attribute = Keyword.fetch!(args, :bin_attribute)

    %State{ball_attribute: ball_attribute, bin_attribute: bin_attribute}
  end

  @impl true
  def proposition_executed(_, _, state), do: state

  # def proposition_executed(
  #   bin_packer,
  #   %MoveProposition{from_bin_id: from_bin_id, to_bin_id: to_bin_id},
  #   state
  # ) do
  # end

  # def proposition_executed(
  #   bin_packer,
  #   %SwapProposition{bin_id: bin_id, other_bin_id: other_bin_id},
  #   state
  # ) do
  # end

  @impl true
  def bin_added(_bin_packer, _bin, state), do: state

  @impl true
  def ball_added(_bin_packer, _ball, state), do: state

  @impl true
  defdelegate cost(bin_packer, state), to: __MODULE__, as: :cost_no_cache

  def cost_no_cache(bin_packer, state) do
    counts =
      bin_packer
      |> Assignments.to_map()
      |> Enum.flat_map(fn {bin, balls} ->
        bin_attribute = bin_attribute(bin, state)

        Enum.map(balls, fn ball ->
          {ball_attribute(ball, state), bin_attribute}
        end)
      end)
      |> Enum.group_by(
        fn {ball_attribute, _bin_attribute} -> ball_attribute end,
        fn {_ball_attribute, bin_attribute} -> bin_attribute end
      )
      |> Enum.into(%{}, fn {ball_attribute, bin_attributes} ->
        counts =
          bin_attributes
          |> Enum.group_by(fn x -> x end)
          |> Enum.into(%{}, fn {bin_attribute, list} -> {bin_attribute, length(list)} end)

        {ball_attribute, counts}
      end)

    all_bin_attributes =
      bin_packer
      |> Assignments.bins()
      |> Enum.map(&bin_attribute(&1, state))
      |> Enum.uniq()

    counts
    |> Enum.into(%{}, fn {ball_attribute, bin_counts} ->
      bin_counts =
        Enum.into(all_bin_attributes, %{}, fn bin_attribute ->
          count = Map.get(bin_counts, bin_attribute, 0)

          {bin_attribute, count}
        end)

      {ball_attribute, Map.values(bin_counts)}
    end)
    |> Map.values()
    |> Enum.map(&std_dev/1)
    |> Enum.sum()
  end

  defp bin_attribute(bin, %State{bin_attribute: bin_attribute_fn}) when is_function(bin_attribute_fn) do
    bin_attribute_fn.(bin)
  end

  defp bin_attribute(bin, %State{bin_attribute: bin_attribute_name}) when is_atom(bin_attribute_name) do
    Bin.attribute(bin, bin_attribute_name)
  end

  defp ball_attribute(ball, %State{ball_attribute: ball_attribute_fn}) when is_function(ball_attribute_fn) do
    ball_attribute_fn.(ball)
  end

  defp ball_attribute(ball, %State{ball_attribute: ball_attribute_name}) when is_atom(ball_attribute_name) do
    Ball.attribute(ball, ball_attribute_name)
  end
end
