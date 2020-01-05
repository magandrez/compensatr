# frozen_string_literal: true

require 'optparse'

# Class in charge of reading and parsing input
class InputParser
  attr_reader :parser, :options

  # Class describing flags and options for script input
  class ScriptOptions
    attr_accessor :target_years, :min_short_term_percent,
                  :min_medium_term_percent, :min_long_term_percent, :target,
                  :file, :money, :groups, :continents, :debug

    def initialize
      # Defaults could be extracted to a file
      # and read from there using
      # e.g.; https://github.com/bkeepers/dotenv
      self.target_years = 1
      self.min_short_term_percent = 0.0
      self.min_medium_term_percent = 0.0
      self.min_long_term_percent = 0.0
      self.target = './data/output.json'
      self.continents = 1
      self.debug = false
    end

    def file_to_parse(parser)
      parser.on('-f <path>',
                '--file <path>',
                String,
                'Source file of projects') do |f|
        self.file = f
      end
    end

    def target_to_serialise(parser)
      parser.on('-t <path>',
                '--target <path>',
                String,
                "Target file where result is stored. \
Defaults to ./data/output.json") do |t|
        self.target = t
      end
    end

    def money_to_use(parser)
      parser.on('-m <value>', '--money <value>',
                Float,
                'Amount of money to be used') do |m|
        self.money = m
      end
    end

    def years_to_report(parser)
      parser.on('--target_years <value>',
                Integer,
                'Target years for C02 optimization, defaults to 1') do |y|
        self.target_years = y
      end
    end

    def min_continents(parser)
      parser.on('--min_continents <value>',
                Integer,
                "Minimum number of continents where projects should be \
distributed, defaults to 1") do |con|
        self.continents = con
      end
    end

    def min_short_group(parser)
      parser.on('--min_short_term_percent <value>',
                Float,
                "Minimum percentage of short term projects to be bought\
, defaults to 0") do |s|
        self.min_short_term_percent = s
      end
    end

    def min_medium_group(parser)
      parser.on('--min_medium_term_percent <value>',
                Float,
                "Minimum percentage of medium term projects to be bought\
, defaults to 0") do |m|
        self.min_medium_term_percent = m
      end
    end

    def min_long_group(parser)
      parser.on('--min_long_term_percent <value>',
                Float,
                "Minimum percentage of long term projects to be bought\
, defaults to 0") do |l|
        self.min_long_term_percent = l
      end
    end

    def debug_flag(parser)
      parser.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        self.debug = v
      end
    end

    def define_options(parser)
      parser.banner = 'Usage: compensatr.rb -f <path> [options]'
      parser.separator 'Options:'
      file_to_parse(parser)
      target_to_serialise(parser)
      money_to_use(parser)
      years_to_report(parser)
      min_continents(parser)
      min_short_group(parser)
      min_medium_group(parser)
      min_long_group(parser)
      debug_flag(parser)
      parser.on_tail('-h', '--help', 'Show options') { puts parser; exit }
    end
  end

  # Reads input into options for the script to use
  # @return [Hash] options
  def parse(args)
    @options = ScriptOptions.new
    OptionParser.new do |parser|
      @options.define_options(parser)
      parser.parse!(args)
    end
    raise OptionParser::MissingArgument if @options.file.nil?

    save_groups!
    @options
  end

  # Bang function to set the group constraints on a
  # separate hash within @options for easy access
  def save_groups!
    @options.groups = {
      min_short_term_percent: @options.min_short_term_percent,
      min_medium_term_percent: @options.min_medium_term_percent,
      min_long_term_percent: @options.min_long_term_percent
    }
  end
end
