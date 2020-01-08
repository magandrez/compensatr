# frozen_string_literal: true

require 'spec_helper'
require './lib/input_parser'

RSpec.describe InputParser do

  describe '#parse' do
    context 'with minimal input' do
      before :each do
        args = ['compensatr.rb',
          "--file", "#{File.expand_path('./spec/fixtures/fixture.json')}",
          "--money", "20"]
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

    context 'with some more input' do
      before :each do
        args = ['compensatr.rb',
          '--file', "#{File.expand_path('./spec/fixtures/fixture.json')}",
          '--money', '20',
          '--min_continents', '3',
          '--min_long_term_percent', '2',
          '--min_medium_term_percent', '2',
          '--min_short_term_percent', '2',
          '--target', "#{File.expand_path('./spec/fixtures/test.json')}",
          '--target_years', '2',
          '-v']
        stub_const('ARGV', args)
      end
      it 'should override defaults' do
        fake_input = InputParser.new
        expect(fake_input).to be_a(InputParser)
        fake_opts = fake_input.parse(ARGV)
        expect(fake_opts.money).to eq 20
        expect(fake_opts.continents).to eq 3
        expect(fake_opts.file).to eq File.expand_path('spec/fixtures/fixture.json')
        expect(fake_opts.debug).to eq true
        expect(fake_opts.min_long_term_percent).to eq 2
        expect(fake_opts.min_medium_term_percent).to eq 2
        expect(fake_opts.min_short_term_percent).to eq 2
        expect(fake_opts.target).to eq File.expand_path('spec/fixtures/test.json')
      end
    end
  end
end
