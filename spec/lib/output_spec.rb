# frozen_string_literal: true

require 'spec_helper'
require './lib/output'

describe Output do
  let(:project) {
    fixture = File.expand_path('./spec/fixtures/fixture.json')
    str = File.read(fixture)
    projects = JSON.parse(str, symbolize_names: true)
    [projects.first]
  }

  # Here the checks could be done for the content
  # grepping for specific matching strings.
  # Instead, the checks are based on the size of the
  # messages.
  describe '#selection_output' do
    context 'with one project as input' do
      it 'should return a string with one project' do
        output = Output.selection_output(project, 1, 1, 1)
        expect(output).to be_a(String)
        expect(output.size).to eq 276
      end
    end

    context 'with no input' do
      it 'should return a string of smaller size' do
         output = Output.selection_output(nil, nil, nil, nil)
        expect(output).to be_a(String)
        expect(output.size).to eq 108
      end
    end
  end

  describe '#new_best_output' do
    context 'with one project as input' do
      it 'should return a string with best values' do
        output = Output.new_best_output(1, 1, 1)
        expect(output).to be_a(String)
        expect(output.size).to eq 186
      end
    end

    context 'with no input' do
      it 'should return a string of smaller size' do
         output = Output.new_best_output(nil, nil, nil)
        expect(output).to be_a(String)
        expect(output.size).to eq 183
      end
    end
  end

  
  describe '#group_representation_output' do
    context 'with one project as input' do
      it 'should return a string with group info data' do
        output = Output.group_representation_output({short: 0, medium: 0, long: 0}, 1)
        expect(output).to be_a(String)
        expect(output.size).to eq 195
      end
    end
  end
end
