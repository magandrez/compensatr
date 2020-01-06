# frozen_string_literal: true

# Module to validate source data to a minimal
# extend.
module DataValidator
  TIME_MAP = {
    'year' => 1,
    'month' => 12,
    'day' => 365
  }.freeze

  # Returns an array of projects
  # with normalised time per project
  # @param [Array] arr
  # @return [Array] arr with std_time per project if all OK
  def self.normalise_time(arr)
    invalid = invalid_time_units(arr).empty?
    unless invalid
      LOGGER.error "Time units are not recognised \
      for projects with id: #{res.map { |r| r[:id] }}. Exiting"
      exit 1
    end

    # Injects std_time field in each project hash with time in years.
    arr.map do |proj|
      proj[:std_time] = (proj[:time].to_f / TIME_MAP[proj[:time_unit]]).round(4)
    end
    arr
  end

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
  # @param [Array] projects to validate time
  # @return [Array] projects with unrecognisable time units
  def self.invalid_time_units(projects)
    units = TIME_MAP.keys
    projects.reject do |pr|
      units.select { |k| pr[:time_unit].match(k) }.any?
    end
  end
end
