# frozen_string_literal: true

# Namespace for logging specific purposes
module Output
  # Outputs best selection string for logging purposes
  # @param [Array] sel
  # @param [Float] val of selection
  # @param [Float] available money
  def self.selection_output(sel, val, spent, available)
    # TODO: guard the plaussible division by zero
    <<~HEREDOC

      Best selection:
      #{sel}

      Best efficiency achieved (in total units of CO2): #{val}
      Money spent over money available: #{spent} / #{available}
    HEREDOC
  end

  # Outputs data for best selection of projects
  # @param [Float] value in CO2 units achieved with selection
  # @param [Float] spent money in selection
  # @param [Integer] continents
  def self.new_best_output(value, spent, continents)
    <<~HEREDOC

      Efficiency of new best selection of projects (in units of CO2): #{value}
      Money spent in new best selection of projects (in money units): #{spent}
      Count of different project locations by continent: #{continents}
    HEREDOC
  end

  # Outputs data related to distribution of projects per group
  # @param [Hash] expenditures with money used in for each group
  # @param [Float] spent money in selection
  def self.group_representation_output(expenditures, spent)
    # TODO: guard the plaussible division by zero
    <<~HEREDOC

      Representation per group:
        - Short term value (in money): #{expenditures[:short]}.
        In percentage #{((expenditures[:short] / spent) * 100).round(2)}%.
        - Medium term value (in money): #{expenditures[:medium]}.
        In percentage #{((expenditures[:medium] / spent) * 100).round(2)}%.
        - Long term value: (in money) #{expenditures[:long]}.
        In percentage #{((expenditures[:long] / spent) * 100).round(2)}%.
    HEREDOC
  end
end
