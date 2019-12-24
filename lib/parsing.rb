# frozen_string_literal: true

OPTIONS = {}.freeze

def parse_cmd!
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

def read_input
  File.read(OPTIONS[:file])
rescue StandardError => e
  puts e.inspect
  exit 1
end

def parse_input(src)
  JSON.parse(src, symbolize_names: true)
rescue JSON::ParserError => e
  puts e
  exit 1
end
