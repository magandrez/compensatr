# frozen_string_literal: true

require 'optparse'
require 'json'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: compensatr.rb -f <path> [options]'
  opts.on('-f', '--file <path>', String, 'Source file of projects')
  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!(into: options)

raise OptionParser::MissingArgument if options[:file].nil?

begin
  source_file = File.read(options[:file])
rescue StandardError => e
  puts e.inspect
  exit 1
end

begin
  hash = JSON.parse(source_file, symbolize_names: true)
rescue JSON::ParserError => e
  puts e
  exit 1
end

puts hash
