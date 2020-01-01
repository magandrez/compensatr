# frozen_string_literal: true

require_relative 'lib/parser'

TIME_MAP = {
  'year' => 1,
  'month' => 12,
  'day' => 365
}.freeze

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


if $PROGRAM_NAME == __FILE__ # Let the script run unless Rspec is the caller
  Parser.read_args
  file = Parser.read_input_file
  exit 1 unless file
  arr = Parser.parse_input(file)
  projects = normalise_time(arr)
  exit 1 if projects.empty?
  enriched_projects = calculate_efficiency(projects)
  full_data = calculate_price_per_unit(enriched_projects)
end
