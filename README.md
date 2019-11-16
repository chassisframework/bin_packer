# BinPacker

*WORK IN PROGRESS*

A [bin-packing](https://en.wikipedia.org/wiki/Bin_packing_problem) constraint solver/optimizer for Elixir.

See the [examples](examples).

Included out of the box:

- Constraints
  - [OnePerBinConstraint](lib/bin_packer/constraints/one_per_bin.ex) - only one ball with a certain attribute value is allowed in the bin (e.g. one dessert per lunchbox)
  - [OnePerGroupConstraint](lib/bin_packer/constraints/one_per_group.ex) - only one ball with a certain attribute value is allowed per bin group (e.g. one admiral per fleet of ships)

- Optimization Objectives
  - [BallsProportionalToBinObjective](lib/bin_packer/objectives/balls_proportional_to_bin.ex) - sum of ball attribute aims to be proportional to bin attribute (e.g. total process load proportional to cpu)
  - [EqualNumBallAttributePerBinObjective](lib/bin_packer/objectives/equal_num_ball_attribute_per_bin.ex) - each bin should aim to contain equal numbers of balls with the same attribute (e.g. each truck contains the same number of fragile boxes)
  - [EqualNumBallAttributePerGroupObjective](lib/bin_packer/objectives/equal_num_ball_attribute_per_group.ex) - each group of bins should aim to contain equal numbers of balls with the same attribute (e.g. each fleet of ships should contain an equal number of science officers)
  - [EqualNumBallBallsPerBinObjective](lib/bin_packer/objectives/equal_num_balls_per_bin.ex) - each bin should contain an equal number of balls (e.g. each album contains the same numer of songs)

# Implementation

Based on the variable-neighborhood [hill-climbing](https://en.wikipedia.org/wiki/Hill_climbing) solver from ["Efficient local search for several combinatorial optimization problems"](docs/53928_BULJUBASIC_2015_archivage_cor.pdf) by Mirsad Buljubašić and ["Variable Neighborhood Search for Google Machine Reassignment problem"](docs/Variable%20Neighborhood%20Search%20for%20Google%20Machine%20Reassignment%20Problem.pdf) by Gavranović, Buljubašić and Demirović, which was designed to solve the [2012 ROADEF/EURO Machine Reassignment Challenge](docs/problem_definition_v1.pdf).

This library generalizes Buljubašić et al's solution by allowing completely custom and pluggable constraints and optimization targets. Additionally, candidate solutions are generated directly by the constraint modules themselves, in order to gradually winnow down the search space as constraints are tested (as opposed to generating random solutions and then testing for constraint violation).

## Installation

The package can be installed by adding `bin_packer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bin_packer, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/bin_packer](https://hexdocs.pm/bin_packer).

