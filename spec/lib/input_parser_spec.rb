# frozen_string_literal: true

require 'spec_helper'
require './lib/input_parser'

RSpec.describe InputParser do
  let(:fixture_path) { File.expand_path('./spec/fixtures/fixture.json') }
  let(:invalid_fixture) {File.read(File.expand_path('./spec/fixtures/invalid.json'))}
  let(:fixture) { File.read(fixture_path) }

  describe '.initialize' do
    context 'with proper input' do
      before :each do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/fixture.json')}"]
        stub_const('ARGV', args)
      end

      it 'should store input in a hash ' do
        fake_input = InputParser.new
        expect(fake_input).to be_a(InputParser)
        fake_opts = fake_input.instance_variable_get(:@params)
        expect(fake_opts).to be_a(Hash)
        expect(fake_opts).to have_key(:file)
        expect(fake_opts[:file]).to eq(fixture_path)
      end
    end

    context 'with improper input' do
      it 'should raise OptionParser::MissingArgument error if no source file is provided' do
        args = ['compensatr.rb', '-f']
        stub_const('ARGV', args)
        expect { InputParser.new }.to raise_error(OptionParser::MissingArgument)
      end
    end
  end

  describe '.read_input_file' do
    context 'with proper input' do
      it 'should return the contents of a file as String' do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/fixture.json')}"]
        stub_const('ARGV', args)
        fake_input = InputParser.new
        expect(fake_input.read_input_file).to be_a(String)
      end
    end

    context 'with improper input' do
      it 'should log an error and return nil if there is any problem accessing the file' do
        args = ['compensatr.rb', "-f#{File.expand_path('./foo/bar/baz.json')}"]
        stub_const('ARGV', args)
        fake_input = InputParser.new
        expect(fake_input.read_input_file).to be nil
      end
    end
  end

  describe '.parse_input' do
    context 'from a file containing valid JSON' do
      it 'should read the content and parse it into Ruby objects' do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/fixture.json')}"]
        stub_const('ARGV', args)
        content = InputParser.new.parse_input(fixture)
        expect(content).to be_a(Array)
        expect(content.size).to be 3
      end
    end

    context 'from a file containing invalid JSON' do
      it 'should return nil' do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/invalid.json')}"]
        stub_const('ARGV', args)
        content = InputParser.new.parse_input(invalid_fixture)
        expect(content).to be nil
      end
    end
  end
end
