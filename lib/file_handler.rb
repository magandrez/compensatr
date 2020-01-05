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
      puts "Error reading file. #{e.inspect}"
      nil
    end
    return nil unless str

    parse_input(str)
  end

  # Parses JSON input string into Ruby objects
  # @param [String] src string
  # @return [Array] Ruby array with src projects
  # @raise [JSON::ParserError] if src string is not valid JSON
  def parse_input(src)
    JSON.parse(src, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Error parsing source data. #{e.inspect}"
    nil
  end

  # Writes data into a file set at input
  # @param [Array] data source with purchase plan and CO2 report
  def write_data(data)
    File.open(@target_file, 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
  end
end
