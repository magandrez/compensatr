# frozen_string_literal: true

require 'spec_helper'
require './lib/parser'

RSpec.describe Parser do
  let(:fixture_path) { File.expand_path('./spec/fixtures/fixture.json') }
  let(:fixture) { File.read(fixture_path) }

  describe '.read_args' do
    context 'with proper input' do
      before :each do
        args = ['compensatr.rb', "-f#{File.expand_path('./spec/fixtures/fixture.json')}"]
        stub_const('ARGV', args)
      end

      it 'should save file info in options constant' do
        expect(Parser.read_args).to be nil
        expect(Parser::OPTIONS).to be_a(Hash)
        expect(Parser::OPTIONS).to have_key(:file)
        expect(Parser::OPTIONS[:file]).to eq(fixture_path)
      end
    end

    context 'with improper input' do
      it 'should raise OptionParser::MissingArgument error if no source file is provided' do
        args = ['compensatr.rb', '-f']
        stub_const('ARGV', args)
        expect { Parser.read_args }.to raise_error(OptionParser::MissingArgument)
      end
    end
  end

  describe '.read_input_file' do
    context 'with proper input' do
      it 'should return the contents of a file as String' do
        stub_const('Parser::OPTIONS', file: fixture_path)
        expect(described_class.read_input_file).to be_a(String)
      end
    end

    context 'with improper input' do
      it 'should log an error and return nil if there is any problem accessing the file' do
        stub_const('Parser::OPTIONS', file: 'foo/bar/baz.json')
        expect(described_class.read_input_file).to be nil
      end
    end
  end

  describe '.parse_input' do
    context 'from a file containing valid JSON' do
      it 'should read the content and parse it into Ruby objects' do
        content = Parser.parse_input(fixture)
        expect(content).to be_a(Array)
        expect(content.size).to be 3
      end
    end

    context 'from unknown source' do
      it 'should log an error and return nil if there is any problem with the source data' do
        content = Parser.parse_input("")
        expect(content).to be nil
      end
    end
  end
end
