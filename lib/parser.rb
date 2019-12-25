# frozen_string_literal: true

require 'json'
require 'optparse'

module Parser
  OPTIONS = {}

  def self.read_args
    OptionParser.new do |opts|
      opts.banner = 'Usage: compensatr.rb -f <path> [options]'
      opts.on('-f', '--file <path>', String, 'Source file of projects')
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end.parse!(into: OPTIONS)

    raise OptionParser::MissingArgument if OPTIONS[:file].nil?
  end

  def self.read_input_file
    File.read(OPTIONS[:file])
  rescue SystemCallError => e
    puts "Error reading file. #{e.inspect}"
    nil
  end

  def self.parse_input(src)
    JSON.parse(src, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Error parsing source data. #{e.inspect}"
    nil
  end
end
