# frozen_string_literal: true

require 'json'

# Handles data serialization from source file
# and to target file.
class FileHandler
  def initialize(src, target)
    @src_file = src
    @target_file = target
  end

  # Reads source file requested by user via $stdin
  # @returns [Array] string of data
  # @raise [SystemCallError] if there is an error reading input file
  def read_data
    begin
      str = File.read(@src_file)
    rescue SystemCallError => e
      LOGGER.error "Error reading file. #{e.inspect}"
      nil
    end
    return nil unless str

    parse_input(str)
  end

  # Parses JSON input string into Ruby objects
  # @param [String] src string
  # @return [Array, nilClass] Ruby array with src projects or nil if error
  def parse_input(src)
    return nil unless valid_json?(src)

    JSON.parse(src, symbolize_names: true) if valid_json?(src)
  end

  # Validates JSON string
  # @param [String] string to be parsed to JSON
  # @raise [JSON::ParserError] if string is not valid JSON
  def valid_json?(string)
    !!JSON.parse(string)
  rescue JSON::ParserError => e
    LOGGER.error "Error parsing data. #{e.inspect}"
    false
  end

  # Writes data into a file set at input
  # @param [Array] data source with purchase plan and CO2 report
  def write_data(data)
    begin
      File.open(@target_file, 'w') do |f|
        f.write(JSON.dump(data))
      end
    rescue SystemCallError => e
      LOGGER.error "Error writting file. #{e.inspect}"
    end
    LOGGER.info "Report written to #{@target_file}"
    nil
  end
end
