# frozen_string_literal: true

require 'spec_helper'
require './lib/data_validator'
require 'json'

describe DataValidator do
  describe '#invalid_time_units' do
    let(:projects) {
      fixture = File.expand_path('./spec/fixtures/fixture.json')
      str = File.read(fixture)
      JSON.parse(str, symbolize_names: true)
    }

    context 'with recognised date units given as data' do
      it 'should return empty array' do
        validation_result = DataValidator.invalid_time_units(projects)
        expect(validation_result).to be_an(Array)
        expect(validation_result.empty?).to be true
      end
    end

    context 'with unrecognised date units given as data' do
      it 'should return an array with first project containing unrecognisable date unit' do
        stub_const('LOGGER', Logger.new(nil))
        allow(LOGGER).to receive(:error).and_return nil
        projects.first[:time_unit] = "week" # Date unit not supported
        validation_result = DataValidator.invalid_time_units(projects)
        expect(validation_result).to be_an(Array)
        expect(validation_result.empty?).to be false
        expect(validation_result.first[:id]).to eq "p1"
      end
    end
  end

  describe '#normalise_time' do
    let(:projects) {
      fixture = File.expand_path('./spec/fixtures/fixture.json')
      str = File.read(fixture)
      JSON.parse(str, symbolize_names: true)
    }

    it 'should return an array of projects with std_time field in years' do
      normalised_arr = DataValidator.normalise_time(projects)
      expect(normalised_arr).to be_an(Array)
      expect(normalised_arr.first[:std_time]).to eq(0.0055) # 2 days in years
    end
  end
end
