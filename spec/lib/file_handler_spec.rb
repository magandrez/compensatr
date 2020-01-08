# frozen_string_literal: true

require 'spec_helper'
require './lib/file_handler'

RSpec.describe FileHandler do

  let(:source_path) { File.expand_path('./spec/fixtures/fixture.json') }
  let(:valid_fixture) { File.read(source_path) }

  describe '#read_data' do
    context 'with proper input' do
      it 'should return the contents of the file parsed' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:error).and_return nil
        handler = FileHandler.new(source_path, nil)
        expect(handler.read_data).to be_a(Array)
      end
    end

    context 'with improper input' do
      it 'should log an error and return nil if there is any problem accessing the file' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:error).and_return nil
        handler = FileHandler.new('foo/bar/baz', nil)
        expect(handler.read_data).to be nil
      end
    end
  end

  describe '#parse_input' do
    context 'from a file containing valid JSON' do
      it 'should read the content and parse it into Ruby objects' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:error).and_return nil
        handler = FileHandler.new(source_path, nil)
        parsed_content = handler.parse_input(valid_fixture)
        expect(parsed_content).to be_a(Array)
        expect(parsed_content.size).to be 3
      end
    end

    context 'from a file containing invalid JSON' do
      it 'should return nil' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:error).and_return nil
        handler = FileHandler.new(source_path, nil)
        parsed_content = handler.parse_input("abc")
        expect(parsed_content).to be nil
      end
    end
  end

  describe '#write_data' do
    context 'with well-formed JSON' do
      it 'should write data to target_file' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:info).and_return nil
        target_path = File.expand_path('./spec/fixtures/test.json')
        handler = FileHandler.new(nil, target_path)
        expect(handler.write_data([])).to eq nil # bytes written
      end
    end
  end
end

