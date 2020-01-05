# frozen_string_literal: true

require_relative 'lib/input_parser'
require_relative 'lib/file_handler'
require 'set'
require 'date'

# Class implementing algorithm to find a suitable selection
# of projects that meet input criteria. The algorithm
# iterates a large amount of times finding out the best selection
# given the restrictions.
class Compensatr
  TIME_MAP = {
    'year' => 1,
    'month' => 12,
    'day' => 365
  }.freeze

  MAX_ITERATIONS = 100_000

  # Returns an array of projects
  # which time unit is not recognised.
  # Generates regular expressions from the
  # standardised time units, matches it against
  # each of the projects' time_unit returning
  # deviations.
  # It is not the main task of this proof-of-concept
  # to provide a robust validation. For that, look
  # into implementing something like dry-validation
  # https://dry-rb.org/gems/dry-validation/1.4/
  # @param [Array] projects
  # @return [Array] projects with unrecognisable time units
  def validate_time_units(projects)
    units = TIME_MAP.keys
    res = projects.reject do |pr|
      units.select { |k| pr[:time_unit].match(k) }.any?
    end
    unless res.empty?
      LOGGER.error "Time units are not recognised \
      for projects with id: #{res.map { |r| r[:id] }}"
    end
    res
  end

  # Returns an array of projects
  # with normalised time per project
  # @param [Array] arr
  # @return [Array] arr with std_time per project
  def normalise_time(arr)
    if arr.empty?
      LOGGER.error 'No projects to normalise time for. Exiting'
      return []
    end
    results = validate_time_units(arr)
    return [] unless results.empty?

    # Injects std_time field in each project hash with time in years.
    arr.map do |proj|
      proj[:std_time] = (proj[:time].to_f / TIME_MAP[proj[:time_unit]]).round(4)
    end
    arr
  end

  # Enriches arr with efficiency (CO2/year)
  # @param [Array] arr
  # @return [Array] arr with efficiency per project
  def calculate_efficiency(arr)
    arr.map do |proj|
      proj[:yearly_co2_vol] = (proj[:co2_volume].to_f /
        proj[:std_time]).round(4)
    end

    arr
  end

  # Validates minimum units for selected project
  # @param [Integer] count of project in selection
  # @param [Hash] proj
  # @return [TrueClass, FalseClass] true if project is within min boundaries
  def meets_min_units(count, proj)
    (count >= proj[:min_units])
  end

  # Validates maximum units for selected project
  # @param [Integer] count of project in selection
  # @param [Hash] proj
  # @return [TrueClass, FalseClass] true if project is within max boundaries
  def meets_max_units(count, proj)
    (count <= proj[:max_units])
  end

  # Each project repetition in the selection array means 1 credit
  # valid_project_constraints validates that the minimum and maximum
  # units per project are met
  # @param [Array] selection of projects
  # @return [TrueClass, FalseClass] true if valid, false otherwise
  def valid_project_constraints(selection)
    reps = selection.each_with_object(Hash.new(0)) { |h1, h2| h2[h1[:id]] += 1 }
    req_reps = selection.all? do |proj|
      count = reps[proj[:id]]
      unless meets_min_units(count, proj) && meets_max_units(count, proj)
        return false
      end

      true
    end

    req_reps
  end

  # Counts the distribution of selected projects per continent
  # @param [Array] projects
  # @param [Integer]
  def count_continents(projects)
    projects.map { |h| h[:continent] }.uniq.size
  end

  # Verifies that the distribution of projects per continent
  # falls within the minimum number of continents required by input
  # @param [Array] selection of projects
  # @param [Integer] minimum continents
  # @return [TrueClass, FalseClass] true if it meets the minimum,
  #   false otherwise
  def valid_min_continents(selection, min_continents)
    count_continents(selection) >= min_continents
  end

  # Adds cost of short term projects in selection
  # @param [Array] projects
  # @return [Float]
  def sum_short_term(projects)
    projects.map do |proj|
      proj[:price] if proj[:group] == 'short_term'
    end.compact.reduce(:+)
  end

  # Adds cost of medium term projects in selection
  # @param [Array] projects
  # @return [Float]
  def sum_medium_term(projects)
    projects.map do |proj|
      proj[:price] if proj[:group] == 'medium_term'
    end.compact.reduce(:+)
  end

  # Adds cost of long term projects in selection
  # @param [Array] projects
  # @return [Float]
  def sum_long_term(projects)
    projects.map do |proj|
      proj[:price] if proj[:group] == 'long_term'
    end.compact.reduce(:+)
  end

  # Summarises the costs of purchasing credits per
  # type of project returning a hash with prices
  # @param [Array] projects
  # @return [Hash] containing added costs per project group
  def add_costs(projects)
    { short: sum_short_term(projects),
      medium: sum_medium_term(projects),
      long: sum_long_term(projects) }
  end

  # Verifies the distribution of money per project group is
  # within the minimum required per group
  # @param [Float, nilClass] value spent in specific project groups
  # value might be nil (lack of projects in said group).
  # @param [Float] expenditure total money spent
  # @param [Float] min money required to be spent per group
  # @return [TrueClass, FalseClass] true if the value spent is above the minimum
  def money_distribution(value, expenditure, min)
    return false unless value

    (value >= expenditure * (min / 100))
  end

  # Aggregates the validations of money distribution per group
  # @param [Hash] sums money per project group
  # @param [Float] total_money spent
  # @param [Hash] groups containing min percentage of money to be spent in group
  # @return [Hash] containing summary of validations per project group
  def validate_min_expenditures(sums, total_money, groups)
    { short: money_distribution(sums[:short],
                                total_money,
                                groups[:min_short_term_percent]),
      medium: money_distribution(sums[:medium],
                                 total_money,
                                 groups[:min_medium_term_percent]),
      long: money_distribution(sums[:long],
                               total_money,
                               groups[:min_long_term_percent]) }
  end

  # Regenerates groups mapping with integers
  # for comparing sets of project groups
  # @param [Hash] groups hash stating minimum percentages of expenditure
  # @return [Hash] groups of expenditures by integer
  def remap_groups(groups)
    groups.reject { |_k, v| v.zero? }
    key_map = { min_short_term_percent: 0,
                min_medium_term_percent: 1,
                min_long_term_percent: 2 }
    groups.transform_keys { |k| key_map[k] }
  end

  # Applies all combinations of possible minimum percentages registered
  # at input time. Comparing arrays in Ruby is not possible with '=='
  # but Set class provides such functionality, hence the casts <Array>.to_set
  # @param [Array] selection of projects
  # @param [Hash] groups specifying minimal expenditure per group
  # @param [Float] money_spent on selection
  def valid_min_groups(selection, groups, money_spent)
    # If no minimums apply, selection is valid
    return true if groups.values.all?(&:zero?)

    summary = add_costs(selection)
    valid = validate_min_expenditures(summary, money_spent, groups)
    groups = remap_groups(groups) # In order to compare sets of integers
    if groups.keys.to_set == [0].to_set
      valid[:short]
    elsif groups.keys.to_set == [1].to_set
      valid[:medium]
    elsif groups.keys.to_set == [2].to_set
      valid[:long]
    elsif groups.keys.to_set == [0, 1].to_set
      valid[:short] && valid[:medium]
    elsif groups.keys.to_set == [0, 2].to_set
      valid[:short] && valid[:long]
    elsif groups.keys.to_set == [1, 2].to_set
      valid[:medium] && valid[:long]
    elsif groups.keys.to_set == [0, 1, 2].to_set
      valid[:short] && valid[:medium] && valid[:long]
    end
  end

  # Agregates projects per project id and adds totals
  # @param [Array] selection of projects
  # @return [Array] aggregated selection of projects per project id
  def aggregate_projects(selection)
    groups = selection.group_by { |h| h[:id] }
    groups.map do |_k, v|
      agg_hash = v.first
      agg_hash[:count] = v.count
      agg_hash[:total_co2_captured] = v.first[:yearly_co2_vol] * v.count
      agg_hash[:finished] = false # A project is finished when std_time is < 0.
      agg_hash
    end
  end

  # Based on the best selection, creates a hash
  # containing the units purchased, the project id and
  # the total price for the operation
  # @param [Array] selection
  # @return [Array] array of hashes containing purchase plan
  def generate_purchase_plan(selection)
    aggregated_projects = aggregate_projects(selection)
    aggregated_projects.map do |proj|
      { 'project_id' => proj[:id],
        'num_units' => proj[:count],
        'price' => (proj[:price] * proj[:count]).round(1) }
    end
  end

  # Based on the best selection, creates a CO2 report of
  # for each of the years requested at input, calculating CO2 captured.
  # Each year might be projects that are not active anymore
  # thus, we don't count them for said year onwards.
  # std_time per project is minused A negative std_time means
  # the project "has finished" (we don't count the potential CO2 captured)
  # @param [Array] selection of most suitable projects
  # @param [Integer] years for which to calculate the CO2 captured
  def generate_co2_report(selection, years)
    aggregated_projects = aggregate_projects(selection)
    this_yr = Date.today.year
    co2_report = (this_yr..this_yr + years).map do |year|
      aggregated_projects.reject! { |proj| proj[:finished] }
      co2_counter = 0
      aggregated_projects.each do |proj|
        co2_counter += proj[:total_co2_captured]
        proj[:std_time] -= 1
        proj[:finished] = true if proj[:std_time].negative?
      end
      { 'year' => year,
        'co2_captured' => co2_counter.round(1) }
    end

    co2_report
  end

  def selection_output(sel, val, spent, available)
    <<~HEREDOC

      Best selection:
      #{sel}

      Best efficiency achieved (in total units of CO2): #{val}
      Money spent over money available: #{spent} / #{available}
    HEREDOC
  end

  def new_best_output(value, spent, sel)
    <<~HEREDOC

      Efficiency of new best selection of projects (in units of CO2): #{value}
      Money spent in new best selection of projects (in money units): #{spent}
      Count of different project locations by continent: #{count_continents(sel)}
    HEREDOC
  end

  def group_representation_output(expenditures, spent)
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

  def run
    parser = InputParser.new
    params = parser.parse(ARGV)
    LOGGER.level = Logger::DEBUG if params.debug
    file_handler = FileHandler.new(params.file, params.target)
    arr = file_handler.read_data
    exit 1 unless arr
    projects = normalise_time(arr)
    exit 1 if projects.empty?
    enriched_projects = calculate_efficiency(projects)

    # Use brute force to create an optimal selection
    best_selection = []
    best_value = 0
    money_spent = 0
    1.upto(MAX_ITERATIONS) do |_i|
      money = params.money
      total_value = 0
      selection = []
      loop do
        pick = enriched_projects.sample
        break if (money - pick[:price]).negative?

        money -= pick[:price]
        selection.append(pick)
        total_value += pick[:yearly_co2_vol]
      end
      next unless valid_project_constraints(selection)
      next unless valid_min_continents(selection, params.continents)
      unless valid_min_groups(selection, params.groups, params.money - money)
        next
      end
      next unless total_value > best_value

      best_selection = selection.dup
      best_value = total_value
      money_spent = params.money - money
      log_new_best = new_best_output(best_value, money_spent, best_selection)
      LOGGER.debug log_new_best
      expenditures = add_costs(best_selection)
      log_group_rep = group_representation_output(expenditures, money_spent)
      LOGGER.debug log_group_rep
    end
    log_best_selection = selection_output(best_selection,
                                          best_value,
                                          money_spent,
                                          params.money)
    LOGGER.info log_best_selection
    purchase_plan = generate_purchase_plan(best_selection)
    co2_report = generate_co2_report(best_selection, params.target_years)
    results = {
      'purchase_plan' => purchase_plan,
      'co2_report' => co2_report
    }
    file_handler.write_data(results)
  end
end
