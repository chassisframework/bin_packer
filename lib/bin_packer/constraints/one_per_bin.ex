defmodule BinPacker.OnePerBinConstraint do

  alias BinPacker.Bin
  alias BinPacker.OnePerGroupConstraint

  @behaviour BinPacker.Constraint

  @impl true
  def init(ball_attribute) do
    OnePerGroupConstraint.init([ball_attribute: ball_attribute, bin_attribute: &Bin.id(&1)])
  end

  @impl true
  defdelegate ball_added(bin_packer, ball, state), to: OnePerGroupConstraint

  @impl true
  defdelegate bin_added(bin_packer, bin, state), to: OnePerGroupConstraint

  @impl true
  defdelegate proposition_executed(bin_packer, proposition, state), to: OnePerGroupConstraint

  @impl true
  defdelegate generate_propositions(bin_packer, proposition, ball_id, state), to: OnePerGroupConstraint

  @impl true
  defdelegate propose_new_placements(bin_packer, ball, state), to: OnePerGroupConstraint

  @impl true
  defdelegate valid_new_placement?(bin_packer, ball, bin_id, state), to: OnePerGroupConstraint

  @impl true
  defdelegate valid_proposition?(bin_packer, proposition, state), to: OnePerGroupConstraint
end
