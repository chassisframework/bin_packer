defmodule BinPacker.EqualNumBallAttributePerBinObjective do
  @moduledoc """
  This objective attempts to place balls into bins such that the given ball attribute is equally represented in each bin.

  This is simply EqualNumBallAttributePerGroupObjective, where the bin attribute is the bin's id.
  """

  alias BinPacker.Bin
  alias BinPacker.EqualNumBallAttributePerGroupObjective

  @behaviour BinPacker.Objective

  @impl true
  def init(ball_attribute) do
    EqualNumBallAttributePerGroupObjective.init([ball_attribute: ball_attribute, bin_attribute: &Bin.id/1])
  end

  @impl true
  defdelegate proposition_executed(bin_packer, proposition, state) , to: EqualNumBallAttributePerGroupObjective

  @impl true
  defdelegate bin_added(bin_packer, bin, state) , to: EqualNumBallAttributePerGroupObjective

  @impl true
  defdelegate ball_added(bin_packer, ball, state) , to: EqualNumBallAttributePerGroupObjective

  @impl true
  defdelegate cost(bin_packer, state) , to: EqualNumBallAttributePerGroupObjective
end
