# frozen_string_literal: true

require 'optparse'
require 'json'
require_relative 'lib/parsing'

parse_cmd!
hash = parse_input(read_input)
puts hash
