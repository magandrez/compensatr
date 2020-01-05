# frozen_string_literal: true

require 'spec_helper'
require './lib/input_parser'

RSpec.describe InputParser do

  describe '#parse' do
    context 'with minimal input' do
      before :each do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/fixture.json')}"]
        stub_const('ARGV', args)
      end

      it 'should give back script defaults and mandatory file input' do
        fake_input = InputParser.new
        expect(fake_input).to be_a(InputParser)
        fake_opts = fake_input.parse(ARGV)
        expect(fake_opts.target_years).to eq 1
        expect(fake_opts.target).to eq './data/output.json'
        expect(fake_opts.continents).to eq 1
        expect(fake_opts.min_long_term_percent).to eq 0.0
        expect(fake_opts.min_medium_term_percent).to eq 0.0
        expect(fake_opts.min_short_term_percent).to eq 0.0
        expect(fake_opts.file).to eq File.expand_path('spec/fixtures/fixture.json')
      end
    end

    context 'with no input' do
      before :each do
        args = ['compensatr.rb']
        stub_const('ARGV', args)
      end
      it 'should raise OptionParser::MissingArgument error' do
        bad_input = InputParser.new
        expect { bad_input.parse(ARGV) }.to raise_error(OptionParser::MissingArgument)
      end
    end

    context 'with some input' do
      before :each do
        args = ['compensatr.rb',
          "-f#{File.expand_path('./spec/fixtures/fixture.json')}",
          "--min_continents","3", "--target_years", "10"]
        stub_const('ARGV', args)
      end
      it 'should override defaults' do
        fake_input = InputParser.new
        expect(fake_input).to be_a(InputParser)
        fake_opts = fake_input.parse(ARGV)
        expect(fake_opts.target_years).to eq 10
        expect(fake_opts.continents).to eq 3
      end
    end
  end
end
