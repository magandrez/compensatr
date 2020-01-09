# frozen_string_literal: true

require_relative 'lib/input_parser'
require_relative 'lib/file_handler'
require_relative 'lib/data_validator'
require_relative 'lib/output'
require 'set'
require 'date'

# Class that implements algorithm to find a suitable selection
# of projects that meet input criteria. The algorithm
# iterates a large amount of times finding out the best selection
# given the restrictions.
class Compensatr
  include DataValidator
  include Output

  MAX_ITERATIONS = 200_000

  # Entrypoint for script. Receives ARGV from
  # console, parses them and quicks in the search
  # for a combination of projects that fit crteria
  # maximising output and minimising cost.
  def run
    start_time = Time.now
    LOGGER.info "Compensatr calculator started."
    # Register input and enrich data
    parser = InputParser.new
    params = parser.parse(ARGV)
    LOGGER.level = Logger::DEBUG if params.debug
    file_handler = FileHandler.new(params.file, params.target)
    arr = file_handler.read_data
    raise StandardError, "No projects to work on. Exiting" if arr.nil?
    projects = DataValidator.normalise_time(arr)
    raise StandardError, "Error normalising time in keys hash." if projects.nil?
    enriched_projects = calculate_efficiency(projects)

    # Use brute force to create an optimal selection
    LOGGER.info "Starting calculation of optimal selection of projects."
    selection, value, money_spent = main_loop(enriched_projects, params)
    LOGGER.info(Output.selection_output(selection,
                                        value,
                                        money_spent,
                                        params.money))
    # At this point, a best selection is reached
    # A "correction round" could be implemented
    # to fill in the remaining value.
    # This is left as improvement similarly as the main loop
    # TODO Implement correction round
    purchase_plan = generate_purchase_plan(selection)
    co2_report = generate_co2_report(selection, params.target_years)
    results = {
      'purchase_plan' => purchase_plan,
      'co2_report' => co2_report
    }
    file_handler.write_data(results)
    LOGGER.info "Search finished. Time spent (in min): #{(Time.now - start_time) / 60}"
  end

  # Brute forces a selection of projects by
  # trial-and-error, saving the most efficient combination
  # between loops and doing constraint checks to validate
  # the selection of projects achieved in each iteration
  #
  # @param [Array] projects source for the selection
  # @param [InputParser] params input by the user with defaults
  def main_loop(projects, params)
    best_selection = []
    money_spent = 0
    best_value = 0
    projects.shuffle!
    1.upto(MAX_ITERATIONS) do |_i|
      money = params.money
      total_value = 0
      selection = []

      # Achieve a selection
      loop do
        pick = projects.sample
        break if (money - pick[:price]).negative?

        money -= pick[:price]
        selection.append(pick)
        total_value += pick[:yearly_co2_vol]
      end
      LOGGER.debug "New selection candidate reached. \
Verfying constraints for selection."
      # Verify the selection is valid or move onto the next iteration
      unless valid_project_constraints(selection)
        LOGGER.debug "New selection candidate failed project constraints.\
 Searching new selection."
        next
      end
      unless valid_min_continents(selection, params.continents)
        LOGGER.debug "New selection candidate failed equitative geographical \
distribution constraint. Searching new selection."
        next
      end
      unless valid_min_groups(selection, params.groups)
        LOGGER.debug "New selection candidate failed equitative group \
distribution constraint. Searching new selection."
        next
      end
      # Is it the best?
      unless total_value > best_value
        LOGGER.debug "New selection candidate is not the best selection recorded. \
Searching new selection."
        next
      end
      LOGGER.debug "New best selection found."
      # If it is better than previous selection, save it
      best_selection = selection.dup
      best_value = total_value
      money_spent = params.money - money
      LOGGER.debug(Output.new_best_output(best_value,
                                          money_spent,
                                          count_continents(best_selection)))
      expenditures = add_costs(best_selection)
      LOGGER.debug(Output.group_representation_output(expenditures,
                                                      money_spent))
    end
    [best_selection, best_value, money_spent]
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
  # It is valid if there is no minimum specified
  #
  # @param [Integer] count of project in selection
  # @param [Hash] proj
  # @return [TrueClass, FalseClass] true if project is within min boundaries
  def meets_min_units(count, proj)
    return true if proj[:min_units].nil?

    (count >= proj[:min_units])
  end

  # Validates maximum units for selected project
  # @param [Integer] count of project in selection
  # @param [Hash] proj
  # @return [TrueClass, FalseClass] true if project is within max boundaries
  def meets_max_units(count, proj)
    return true if proj[:max_units].nil?

    (count <= proj[:max_units])
  end

  # Each project repetition in the selection array means 1 credit
  # valid_project_constraints validates that the minimum and maximum
  # units per project are met
  #
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
  # Does not count 'nil' values for continent key in project
  # @TODO validate continent input
  #
  # @param [Array] projects
  # @return [Integer]
  def count_continents(projects)
    projects.map do |h|
      h[:continent]
    end.compact.uniq.size
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

  # Adds cost of projects in selection by group
  # @TODO Validate group tags,
  # for now if not exact match nothing is added
  #
  # @param [Array] projects
  # @return [Float]
  def sum_prices_for_group(projects, term)
    projects.map do |proj|
      proj[:price].to_f if proj[:group] == term
    end.compact.reduce(:+)
  end

  # Summarises the costs of purchasing credits per
  # type of project returning a hash with prices
  #
  # @param [Array] projects
  # @return [Hash] containing added costs per project group
  def add_costs(projects)
    { short: sum_prices_for_group(projects, 'short_term'),
      medium: sum_prices_for_group(projects, 'medium_term'),
      long: sum_prices_for_group(projects, 'long_term') }
  end

  # Verifies the distribution of money per project group is
  # within the minimum required per group.
  # It is not valid if no value is provided and minimum required is above 0
  # It is valid if there is no minimum.
  #
  # @param [Float, nilClass] value spent in specific project groups
  #   value might be nil (lack of projects in said group).
  # @param [Float] expenditure total money spent
  # @param [Float] min money required to be spent per group
  # @return [TrueClass, FalseClass] true if the value spent is above the minimum
  def money_distribution(value, expenditure, min)
    return false if value.nil? && min.to_f.positive?
    return true if min.to_f.zero? # cast to float converts nils to 0.0

    (value.to_f >= expenditure.to_f * (min.to_f / 100))
  end

  # Aggregates the validations of money distribution per group
  #
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
  # Leaves out from the map requirements without min expenditure.
  #
  # @param [Hash] groups hash stating minimum percentages of expenditure
  # @return [Hash] groups of expenditures by integer
  def remap_groups(groups)
    groups.reject! { |_k, v| v.zero? }
    key_map = { min_short_term_percent: 0,
                min_medium_term_percent: 1,
                min_long_term_percent: 2 }
    groups.transform_keys { |k| key_map[k] }
  end

  # Applies all combinations of possible minimum percentages registered
  # at input time. Comparing arrays in Ruby is not possible with '=='
  # but Set class provides such functionality, hence the casts <Array>.to_set
  # Does so by mapping the inputs (mapped in integers)
  #
  # @param [Array] selection of projects
  # @param [Hash] groups specifying minimal expenditure per group
  # @return [TrueClass, FalseClass] true if the selection is representative
  #         to the minimum required by input
  def valid_min_groups(selection, groups)
    # If no minimums apply, selection is valid
    return true if groups.values.all?(&:zero?)

    summary = add_costs(selection)
    # remove possible nils from add_costs and calculate money spent in selection
    money_spent = summary.values.compact.reduce(:+)
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
  #
  # @param [Array] selection of projects
  # @return [Array] aggregated selection of projects per project id
  def aggregate(selection)
    groups = selection.group_by { |h| h[:id] }
    groups.map do |k, v|
      agg_hash = v.first
      agg_hash[:count] = v.count
      agg_hash[:total_co2_captured] = v.first[:yearly_co2_vol] * v.count
      agg_hash[:finished] = false # A project is finished when std_time is < 0.

      groups[k] = agg_hash
    end
  end

  # Based on the best selection, creates a hash
  # containing the units purchased, the project id and
  # the total price for the operation
  #
  # @param [Array] selection
  # @return [Array] array of hashes containing purchase plan
  def generate_purchase_plan(selection)
    if selection.empty?
      LOGGER.info('No selection reached. Returning empty plan.')
      return [{}]
    end
    aggregated_projects = aggregate(selection)
    aggregated_projects.map do |proj|
      { 'project_id' => proj[:id],
        'num_units' => proj[:count],
        'price' => (proj[:price] * proj[:count]).round(1) }
    end
  end

  # Calculates the years for which the script needs
  # to calculate the report.
  #
  # @param [Integer] years. Min is 1 by default
  # @return [Array] array of years for which to generate the CO2 report
  #    or empty array if no years specified.
  def years_to_report(years)
    unless years && years >= 1
      LOGGER.error 'Report length not specified.'
      return []
    end
    this_yr = Date.today.year
    final_yr = this_yr + (years - 1)
    (this_yr..final_yr).to_a
  end

  # Based on the best selection, creates a CO2 report
  # for each of the years requested at input.
  #
  # NOTE: Opinionated implementation ahead
  #
  # Each turning year might be projects that are not active anymore
  # since its "time" field is a constant given as part of the
  # input data. This implementation
  # *does not count* 'expired projects' to generate the CO2 report
  # after "time" has passed when accumulating data creating the report.
  # "std_time" per project is minused for this reason, to select
  # those projects that are active year after year based on user input.
  # A negative std_time means the project "has finished"
  # thus: its "potential CO2 captured" is not counted.
  # This becomes apparent as the CO2 captured total is skewed towards
  # the present year (i.e.: the closest to "today" the larger the CO2 captured).
  #
  # @param [Array] selection of most suitable projects
  # @param [Integer] years for which to calculate the CO2 captured
  # @return [Array] array of hashes containing CO2 captured per year.
  def generate_co2_report(selection, years)
    if selection.empty?
      LOGGER.info('No selection reached. Returning empty report.')
      return [{}]
    end
    report_length = years_to_report(years)
    return [{}] if report_length.empty?

    aggregated_projects = aggregate(selection)
    co2_report = report_length.map do |year|
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
end
