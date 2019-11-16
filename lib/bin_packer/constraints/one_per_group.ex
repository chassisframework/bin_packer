defmodule BinPacker.OnePerGroupConstraint do
  @moduledoc """
  Constrains the solutions to those where only one bin in a group of bins that share the same attribute may have a ball
  with another attribute value.

  For example,
   In the "machine assignment" scenario: With machines as bins, processes as balls, processes belong to different
   services and machines belong to datacenters. You only want one process from each service to be placed per datacenter,
   to ensure service survivability when a datacenter goes down.
  """

  require BinPacker.Util

  alias BinPacker, as: BinPacker
  alias BinPacker.Assignments
  alias BinPacker.Bin
  alias BinPacker.Ball
  alias BinPacker.MoveProposition
  alias BinPacker.SwapProposition
  alias BinPacker.Util

  @behaviour BinPacker.Constraint

  defmodule State do
    @moduledoc false

    defstruct [
      :ball_attribute_name,
      # atom or function
      :bin_attribute,
      # group names (bin attribute value) -> bin ids
      bin_ids: Map.new(),
      # group names (bin attribute value) -> attribute values
      attributes: Map.new()
    ]
  end

  @impl true
  def init(args) do
    ball_attribute_name = Keyword.fetch!(args, :ball_attribute)
    bin_attribute = Keyword.fetch!(args, :bin_attribute)

    %State{ball_attribute_name: ball_attribute_name, bin_attribute: bin_attribute}
  end

  @impl true
  def ball_added(bin_packer, ball, state) do
    group_name =
      bin_packer
      |> Assignments.bin_for_ball_id(Ball.id(ball))
      |> bin_attribute(state)

    add_ball_to_group(state, ball, group_name)
  end

  @impl true
  def bin_added(
    _bin_packer,
    bin,
    %State{bin_ids: bin_ids, attributes: attributes} = state
  ) do
    group_name = bin_attribute(bin, state)

    bin_ids =
      bin_ids
      |> Map.put_new(group_name, MapSet.new())
      |> Map.update!(group_name, fn group -> MapSet.put(group, Bin.id(bin)) end)

    attributes = Map.put_new(attributes, group_name, MapSet.new())

    %State{state | bin_ids: bin_ids, attributes: attributes}
  end

  @impl true
  def proposition_executed(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    %MoveProposition{ball_id: ball_id,
                     from_bin_id: from_bin_id,
                     to_bin_id: to_bin_id},
    state
  ) do
    ball = Map.get(balls, ball_id)

    current_group = bin_group(bin_packer, from_bin_id, state)
    new_group = bin_group(bin_packer, to_bin_id, state)

    state
    |> remove_ball_from_group(ball, current_group)
    |> add_ball_to_group(ball, new_group)
  end

  def proposition_executed(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    %SwapProposition{ball_id: ball_id,
                     other_ball_id: other_ball_id,
                     bin_id: bin_id,
                     other_bin_id: other_bin_id},
    state
  ) do
    ball = Map.get(balls, ball_id)
    other_ball = Map.get(balls, other_ball_id)

    group = bin_group(bin_packer, bin_id, state)
    other_group = bin_group(bin_packer, other_bin_id, state)

    state
    |> remove_ball_from_group(ball, group)
    |> remove_ball_from_group(other_ball, other_group)
    |> add_ball_to_group(ball, other_group)
    |> add_ball_to_group(other_ball, group)
  end

  # balls can move within this current group, or to other groups that don't have that ball's attribute
  @impl true
  def generate_propositions(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    MoveProposition,
    ball_id,
    %State{bin_ids: bin_ids} = state
  ) do
    current_bin_id = Assignments.bin_id(bin_packer, ball_id)
    current_group = bin_group(bin_packer, current_bin_id, state)

    bins_in_current_group = Map.get(bin_ids, current_group)

    balls
    |> Map.get(ball_id)
    |> bins_without_attribute(state)
    |> Enum.concat(bins_in_current_group)
    |> Enum.reject(fn bin_id -> bin_id == current_bin_id end)
    |> Enum.map(&MoveProposition.new(bin_packer, ball_id, &1))
    |> Util.detect_invalid_propositions(bin_packer, state)
    |> Util.stream_from_list()
  end

  # a ball can be swapped with:
  # - any ball that shares the same attribute
  # OR
  # - any ball that:
  #    - is in a group that doesn't have this ball's attribute
  #    AND
  #    - has an attribute that this group doesn't already have
  def generate_propositions(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    SwapProposition,
    ball_id,
    %State{ball_attribute_name: ball_attribute_name, bin_ids: bin_ids, attributes: attributes} = state
  ) do
    ball = Map.get(balls, ball_id)
    bin_id = Assignments.bin_id_for_ball_id(bin_packer, ball_id)
    attribute = Ball.attribute(ball, ball_attribute_name)
    group = bin_group(bin_packer, bin_id, state)
    group_attributes = Map.get(attributes, group)

    {groups_with_attribute, groups_without_attribute} =
      attributes
      |> Map.keys()
      |> Enum.split_with(fn group -> attribute_in_group?(ball, group, state) end)

    balls_with_attribute =
      groups_with_attribute
      |> Enum.flat_map(fn group -> Map.get(bin_ids, group) end)
      |> Enum.flat_map(fn bin_id -> Assignments.balls_for_bin_id(bin_packer, bin_id) end)
      |> Enum.filter(fn other_ball ->
        attribute == Ball.attribute(other_ball, ball_attribute_name)
      end)
      |> Enum.map(&Ball.id/1)
      |> Enum.reject(fn other_ball_id -> ball_id == other_ball_id end)

    balls_from_bins_without_conflicting_attributes =
      groups_without_attribute
      |> Enum.flat_map(fn group -> Map.get(bin_ids, group) end)
      |> Enum.flat_map(fn bin_id ->
        bin_packer
        |> Assignments.balls_for_bin_id(bin_id)
        |> Enum.reject(fn other_ball ->
          other_attribute = Ball.attribute(other_ball, ball_attribute_name)
          MapSet.member?(group_attributes, other_attribute)
        end)
      end)
      |> Enum.map(&Ball.id/1)

    balls_with_attribute
    |> Enum.concat(balls_from_bins_without_conflicting_attributes)
    |> Enum.map(&SwapProposition.new(bin_packer, ball_id, &1))
    |> Util.detect_invalid_propositions(bin_packer, state)
    |> Util.stream_from_list()
  end

  @impl true
  def propose_new_placements(_bin_packer, ball, state) do
    ball
    |> bins_without_attribute(state)
    |> Util.stream_from_list()
  end

  @impl true
  def valid_new_placement?(bin_packer, ball, bin_id, state) do
    new_group = bin_group(bin_packer, bin_id, state)

    !attribute_in_group?(ball, new_group, state)
  end

  @impl true
  def valid_proposition?(_bin_packer, %MoveProposition{from_bin_id: same_bin_id, to_bin_id: same_bin_id}, _state),  do: false

  def valid_proposition?(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    %MoveProposition{ball_id: ball_id, from_bin_id: from_bin_id, to_bin_id: to_bin_id},
    %State{bin_ids: bin_ids} = state
  ) do
    ball = Map.get(balls, ball_id)

    current_group = bin_group(bin_packer, from_bin_id, state)
    new_group = bin_group(bin_packer, to_bin_id, state)

    intra_group_move =
      bin_ids
      |> Map.get(current_group)
      |> MapSet.member?(to_bin_id)

    intra_group_move || !attribute_in_group?(ball, new_group, state)
  end

  def valid_proposition?(_bin_packer, %SwapProposition{ball_id: same_ball_id, other_ball_id: same_ball_id}, _state), do: false
  def valid_proposition?(_bin_packer, %SwapProposition{bin_id: same_bin_id, other_bin_id: same_bin_id}, _state), do: false

  def valid_proposition?(
    %BinPacker{assignments: %Assignments{balls: balls}} = bin_packer,
    %SwapProposition{ball_id: ball_id,
                     other_ball_id: other_ball_id,
                     bin_id: bin_id,
                     other_bin_id: other_bin_id},
    %State{ball_attribute_name: ball_attribute_name} = state
  ) do
    ball = Map.get(balls, ball_id)
    other_ball = Map.get(balls, other_ball_id)

    attribute = Ball.attribute(ball, ball_attribute_name)
    other_attribute = Ball.attribute(other_ball, ball_attribute_name)

    if attribute == other_attribute do
      true
    else
      group = bin_group(bin_packer, bin_id, state)
      other_group = bin_group(bin_packer, other_bin_id, state)

      !attribute_in_group?(ball, other_group, state) &&
        !attribute_in_group?(other_ball, group, state)
    end
  end


  defp bins_without_attribute(
    ball,
    %State{
      bin_ids: bin_ids,
      attributes: attributes
    } = state
  ) do
    Enum.flat_map(attributes, fn {group, _group_attributes} ->
      if attribute_in_group?(ball, group, state) do
        []
      else
        bin_ids
        |> Map.get(group)
        |> MapSet.to_list()
      end
    end)
  end

  defp remove_ball_from_group(
    %State{
      ball_attribute_name: ball_attribute_name,
      attributes: attributes
    } = state,
    ball,
    group
  ) do
    attribute = Ball.attribute(ball, ball_attribute_name)

    if !attribute_in_group?(ball, group, state) do
      raise "ball attribute #{inspect(attribute)} not found in group #{inspect(group)}, this is a bug!"
    end

    attributes =
      Map.update!(attributes, group, fn group_attributes ->
        MapSet.delete(group_attributes, attribute)
      end)

    %State{state | attributes: attributes}
  end

  defp add_ball_to_group(
    %State{
      ball_attribute_name: ball_attribute_name,
      attributes: attributes
    } = state,
    ball,
    group
  ) do
    attribute = Ball.attribute(ball, ball_attribute_name)

    if attribute_in_group?(ball, group, state) do
      raise "ball attribute #{inspect(attribute)} already in group #{inspect(group)}, this is a bug!"
    end

    attributes =
      Map.update!(attributes, group, fn group_attributes ->
        MapSet.put(group_attributes, attribute)
      end)

    %State{state | attributes: attributes}
  end

  defp bin_group(
    %BinPacker{assignments: %Assignments{bins: bins}},
    bin_id,
    state
  ) do
    bins
    |> Map.get(bin_id)
    |> bin_attribute(state)
  end

  defp attribute_in_group?(
         ball,
         group,
         %State{ball_attribute_name: ball_attribute_name, attributes: attributes}
       ) do
    attribute = Ball.attribute(ball, ball_attribute_name)

    attributes
    |> Map.get(group)
    |> MapSet.member?(attribute)
  end

  defp bin_attribute(bin, %State{bin_attribute: bin_attribute_fn}) when is_function(bin_attribute_fn) do
    bin_attribute_fn.(bin)
  end

  defp bin_attribute(bin, %State{bin_attribute: bin_attribute_name}) when is_atom(bin_attribute_name) do
    Bin.attribute(bin, bin_attribute_name)
  end
end
