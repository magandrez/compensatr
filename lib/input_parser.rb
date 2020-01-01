# frozen_string_literal: true

require 'json'
require 'optparse'

class InputParser

  attr_reader :params

  def initialize
    @params = read_args
  end

  def read_args
    # Default parameters
    # Could be extracted to a file and read from there
    # using, e.g. https://github.com/bkeepers/dotenv
    params = {
      min_continents: 1,
      min_short_term_percent: 0.0,
      min_medium_term_percent: 0.0,
      min_long_term_percent: 0.0
    }
    OptionParser.new do |opts|
      opts.banner = 'Usage: compensatr.rb -f <path> [options]'
      opts.on('-f <path>', '--file <path>', String, 'Source file of projects')
      opts.on('-m <value>', '--money <value>', Float, 'Amount of money to be used')
      opts.on('-c <value>', '--min_continents <value>', Integer, 'Minimum number of continents where projects should be distributed, defaults to 1')
      opts.on('--min_short_term_percent <value>', Float, 'Minimum percentage of short term projects to be bought, defaults to 0')
      opts.on('--min_medium_term_percent <value>', Float, 'Minimum percentage of medium term projects to be bought, defaults to 0')
      opts.on('--min_long_term_percent <value>', Float, 'Minimum percentage of long term projects to be bought, defaults to 0')
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end.parse!(into: params)

    raise OptionParser::MissingArgument if params[:file].nil?

    group_keys = [ :min_short_term_percent,
      :min_medium_term_percent,
      :min_long_term_percent ]
    min_groups = params.select {|k, v| group_keys.include?(k) }
    params[:groups] = min_groups
    params
  end

  def read_src_data
    file = read_input_file
    return unless file
    parse_input(file)
  end

  def read_input_file
    File.read(@params[:file])
  rescue SystemCallError => e
    puts "Error reading file. #{e.inspect}"
    nil
  end

  def parse_input(src)
    JSON.parse(src, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Error parsing source data. #{e.inspect}"
    nil
  end
end
