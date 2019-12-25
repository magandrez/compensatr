# frozen_string_literal: true

require_relative 'lib/parser'

Parser.read_args
file = Parser.read_input_file
exit 1 unless file
hash = Parser.parse_input(file)
puts hash
