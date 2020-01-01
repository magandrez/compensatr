# frozen_string_literal: true

require 'json'
require 'optparse'

class InputParser

  attr_reader :options

  def initialize
    @options = read_args
  end

  def read_args
    options = {}
    OptionParser.new do |opts|
      opts.banner = 'Usage: compensatr.rb -f <path> [options]'
      opts.on('-f', '--file <path>', String, 'Source file of projects')
      opts.on('-m', '--money <value>', Float, 'Amount of money to be used')
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end.parse!(into: options)

    raise OptionParser::MissingArgument if options[:file].nil?

    options
  end

  def read_src_data
    file = read_input_file
    return unless file
    parse_input(file)
  end

  def read_input_file
    File.read(@options[:file])
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
