# frozen_string_literal: true

require_relative 'lib/input_parser'
require 'set'

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
# It is not the main task of this proof-of-concep
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
    puts "ERROR: Time units are not recognised \
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
    puts 'ERROR: No projects to normalise time for. Exiting'
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
    proj[:yearly_co2_vol] = (proj[:co2_volume].to_f / proj[:std_time]).round(4)
  end

  arr
end

# Enriches array with price per unit of CO2
# captured per year
# @param [Array] array
# @return [Array] array with price per unit per project
def calculate_price_per_unit(array)
  array.map do |proj|
    proj[:yearly_price] = (proj[:yearly_co2_vol] / proj[:price]).round(2)
  end

  array
end

def valid_project_constraints(selection)
  reps = selection.each_with_object(Hash.new(0)) { |h1, h2| h2[h1[:id]] += 1 }
  req_reps = selection.all? do |proj|
    reps_in_proj = reps[proj[:id]]
    return false unless(reps_in_proj >= proj[:min_units]) &&  (reps_in_proj <= proj[:max_units])
    true
  end

  req_reps
end

def count_continents(projects)
  projects.map { |h| h[:continent] }.uniq.size
end

def valid_min_continents(selection, min_continents)
  count_continents(selection) >= min_continents
end

def summarise_expenditure(projects)
  sum_short = projects.map {|proj| proj[:price] if proj[:group] == "short_term" }.compact.reduce(:+)
  sum_medium = projects.map {|proj| proj[:price] if proj[:group] == "medium_term" }.compact.reduce(:+)
  sum_long = projects.map {|proj| proj[:price] if proj[:group] == "long_term" }.compact.reduce(:+)

  return { short: sum_short.to_f,
    medium: sum_medium.to_f,
    long: sum_long.to_f }
end

def validate_min_expenditures(sums, expenditure, groups)
  # sum might be nil (lack of projects in said group)
  # !! converts nil into a boolean
  short_term_ok = !!sums[:short] && (sums[:short] >= expenditure * (groups[:min_short_term_percent]/100))
  medium_term_ok = !!sums[:medium] && (sums[:medium] >= expenditure * (groups[:min_medium_term_percent]/100))
  long_term_ok = !!sums[:long] && (sums[:long] >= expenditure * (groups[:min_long_term_percent]/100))

  return { short: short_term_ok,
    medium: medium_term_ok,
    long: long_term_ok}
end

def remap_groups(groups)
  groups.reject { |k, v| v == 0 }
  key_map = { min_short_term_percent: 0,
    min_medium_term_percent: 1,
    min_long_term_percent: 2}
  groups.transform_keys {|k| key_map[k]}
end

def valid_min_groups(selection, groups, money_spent)
  return true if groups.values.all? {|g| g == 0 } # If no minimums apply, selection is valid
  summary = summarise_expenditure(selection)
  valid = validate_min_expenditures(summary, money_spent, groups)
  groups = remap_groups(groups)
  # Comparing arrays in Ruby is not possible with ==
  # but Set class provides such functionality
  # hence the casts <Array>.to_set
  case
  when groups.keys.to_set == [0].to_set
    valid[:short]
  when groups.keys.to_set == [1].to_set
    valid[:medium]
  when groups.keys.to_set == [2].to_set
    valid[:long]
  when groups.keys.to_set == [0,1].to_set
    valid[:short] && valid[:medium]
  when groups.keys.to_set == [0,2].to_set
    valid[:short] && valid[:long]
  when groups.keys.to_set == [1,2].to_set
    valid[:medium] && valid[:long]
  when groups.keys.to_set == [0,1,2].to_set
    valid[:short] && valid[:medium] && valid[:long]
  end
end


if $PROGRAM_NAME == __FILE__ # Let the script run unless Rspec is the caller
  cmd_input = InputParser.new
  params = cmd_input.params
  arr = cmd_input.read_src_data
  exit 1 unless arr
  projects = normalise_time(arr)
  exit 1 if projects.empty?
  enriched_projects = calculate_efficiency(projects)
  full_data = calculate_price_per_unit(enriched_projects)

  # Use brute force to create an optimal selection
  best_selection = []
  best_value = 0
  money_spent = 0
  1.upto(MAX_ITERATIONS) do |i|
    money = params[:money]
    total_value = 0
    selection = []
    while true
      pick = full_data.shuffle.sample
      break if (money - pick[:price]) < 0
      money -= pick[:price]
      selection.append(pick)
      total_value += pick[:yearly_co2_vol]
    end
    next unless valid_project_constraints(selection)
    next unless valid_min_continents(selection, params[:min_continents])
    next unless valid_min_groups(selection, params[:groups], params[:money] - money)
    if total_value > best_value
      best_selection = selection.dup
      best_value = total_value
      money_spent = params[:money] - money
      puts "Efficiency of new best selection of projects (in units of CO2): #{best_value}"
      puts "Money spent in new best selection of projects (in money units): #{money_spent}"
      puts "Count of different project locations by continent: #{count_continents(best_selection)}"
      expenditures = summarise_expenditure(best_selection)
      puts "Representation per group: "
      puts "  Short term value (in money units): #{expenditures[:short].to_f}. In percentage #{((expenditures[:short].to_f/money_spent)*100).round(2)}%."
      puts "  Medium term value (in money units): #{expenditures[:medium].to_f}. In percentage #{((expenditures[:medium].to_f/money_spent)*100).round(2)}%"
      puts "  Long term value: (in money units) #{expenditures[:long].to_f}. In percentage #{((expenditures[:long].to_f/money_spent)*100).round(2)}%"
      puts "++++++++++++"
    end
  end
  puts "------------"
  puts "Best selection: #{best_selection}"
  puts "Best efficiency achieved (in total units of CO2): #{best_value}"
  puts "Money spent: #{money_spent} / #{params[:money]}"
end
