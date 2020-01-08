# frozen_string_literal: true

require 'spec_helper'
require './compensatr'

describe Compensatr do

  before :each do
    args = ['compensatr.rb',
      "-f#{File.expand_path('./spec/fixtures/fixture.json')}", "-m", "10"]
    stub_const('ARGV', args)
  end

  let(:params) {
    input = InputParser.new
    input.parse(ARGV)
  }
  let(:projects) {
    f = FileHandler.new(params.file, params.target)
    DataValidator.normalise_time(f.read_data)
  }
  let(:compensatr) { Compensatr.new }

  describe '#calculate_efficiency' do
    context 'with standard input' do
      it 'should return an array with projects stating the CO2 captured per year' do
        arr_projects = [projects.first] # No need to test with more than 1 project in arr
        enriched_arr = compensatr.calculate_efficiency(arr_projects)
        expect(enriched_arr).to be_an(Array)
        expect(enriched_arr.first).to include(:yearly_co2_vol)
        expect(enriched_arr.first[:yearly_co2_vol]).to be_a(Float)
        expect(enriched_arr.first[:yearly_co2_vol]).to be_positive
      end
    end

    context 'with funky project values' do
      it 'should not capture CO2 if the project does not register CO2 volume' do
        c = Compensatr.new
        projects.first[:co2_volume] = 0
        arr_projects = [projects.first]
        enriched_arr = compensatr.calculate_efficiency(arr_projects)
        expect(enriched_arr).to be_an(Array)
        expect(enriched_arr.first).to include(:yearly_co2_vol)
        expect(enriched_arr.first[:yearly_co2_vol]).to be_a(Float)
        expect(enriched_arr.first[:yearly_co2_vol]).to be_zero
      end
    end
  end

  describe '#meets_min_units' do
    context 'when the CO2 units count for a project in selection is bigger than minimum required' do
      it 'should return true' do
        count = 100000
        meets_min = compensatr.meets_min_units(count, projects.first)
        expect(meets_min).to be true
      end
    end

    context 'when the CO2 units count for a project in selection is smaller than minimum required' do
      it 'should return false' do
        count = -1 # Making sure it is smaller than requirements
        meets_min = compensatr.meets_min_units(count, projects.first)
        expect(meets_min).to be false
      end
    end

    context 'when the min CO2 units are not specified' do
      it 'should assume minimum units required for project is 0' do
        count = 1
        projects.first[:min_units] = nil
        meets_min = compensatr.meets_min_units(count, projects.first)
        expect(meets_min).to be true
      end
    end
  end

  describe '#meets_max_units' do
    context 'when the CO2 units count for a project in selection is smaller than maximum required' do
      it 'should return true' do
        count = 1
        projects.first[:max_units] = 100000
        meets_max = compensatr.meets_max_units(count, projects.first)
        expect(meets_max).to be true
      end
    end

    context 'when the CO2 units count for a project in selection is bigger than maximum required' do
      it 'should return false' do
        count = 100000
        meets_max = compensatr.meets_max_units(count, projects.first)
        expect(meets_max).to be false
      end
    end

    context 'when the max CO2 units are not specified' do
      it 'should assume maximum units required for project is 0' do
        count = 1
        projects.first[:max_units] = nil
        meets_max = compensatr.meets_max_units(count, projects.first)
        expect(meets_max).to be true
      end
    end
  end

  describe '#valid_project_constraints' do
    context 'when project contraints are met' do
      it 'should return true' do
        # Make a selection of two projects (first and last)
        selection = [projects.first, projects.last]
        # Fake that the constraints are met for the selection
        allow(compensatr).to receive(:meets_min_units).and_return(true)
        allow(compensatr).to receive(:meets_max_units).and_return(true)
        # Verify the result
        selection = compensatr.valid_project_constraints(projects)
        expect(selection).to be true
      end
    end

    context 'when not all project contraints are met' do
      it 'should return false' do
        # Make a selection of two projects (first and last)
        selection = [projects.first, projects.last]
        # Fake that only the minimum constraint is met for selection
        allow(compensatr).to receive(:meets_min_units).and_return(true)
        allow(compensatr).to receive(:meets_max_units).and_return(false)
        # Verify the result
        selection = compensatr.valid_project_constraints(projects)
        expect(selection).to be false
      end
    end

    context 'when selection contains too many repetitions of a project' do
      it 'should return false' do
        # 1000 p1 in selection will fail to meet max_units constraint
        selection = Array.new(1000, projects.first)
        sel_not_ok = compensatr.valid_project_constraints(selection)
        expect(sel_not_ok).to be false
      end
    end

    context 'when selection contains too few repetitions of a project' do
      it 'should return false' do
        # p1 min_units is 2 so a selection with one repetition will fail
        selection = [projects.first]
        sel_not_ok = compensatr.valid_project_constraints(selection)
        expect(sel_not_ok).to be false
      end
    end
  end

  describe '#count_continents' do
    context 'one single continent in selection' do
      it 'should return 1' do
        selection = Array.new(100, projects.first)
        different_continents = compensatr.count_continents(selection)
        expect(different_continents).to be 1
      end
    end

    context 'when selection contains different continents' do
      it 'should return number of continents in fixture' do
        # NOTE the sample fixture contains only three projects from 2 continents
        different_continents = compensatr.count_continents(projects)
        expect(different_continents).to be 2
      end
    end

    context 'selection contains no information about continents' do
      it 'should not count nil continents' do
        projects.first[:continent] = nil
        selection = [projects.first]
        result = compensatr.count_continents(selection)
        expect(result).to be 0
      end
    end
  end

  describe '#valid_min_continents' do
    context 'when the minimum continents required at input time is valid' do
      it 'should return true' do
        # Fixture contains three projects from 2 continents
        result = compensatr.valid_min_continents(projects, 1)
        expect(result).to be true
      end
    end

    context 'when the minimum continents required at input time is not valid' do
      it 'should return false' do
        # Fixture contains three projects from 2 continents
        result = compensatr.valid_min_continents(projects, 6)
        expect(result).to be false
      end
    end

    context 'when the selection of projects contains nils' do
      it 'should return true if the minimum number of continents in selection is achieved' do
        projects.first[:continent] = nil
        projects.last[:continent] = nil
        # Only one valid continent
        result = compensatr.valid_min_continents(projects, 1)
        expect(result).to be true
      end

      it 'should return false if the minimum number of continents in selection is not achieved' do
        projects.first[:continent] = nil
        projects.last[:continent] = nil
        # Only one valid continent
        result = compensatr.valid_min_continents(projects, 1)
        expect(result).to be true
      end
    end
  end

  describe '#sum_short_term' do
    context 'given a selection of projects for a term' do
      it 'should add prices for projects in selection' do
        # The price per unit for the first project is 232
        selection = [projects.first, projects.first]
        result = compensatr.sum_prices_for_group(selection, 'short_term')
        expect(result).to be_a(Float)
        expect(result).to eq 464.0
      end
    end

    context 'given a selection with nil prices' do
      it 'should add up only numeric prices' do
        first = projects.first.clone
        first[:price] = nil
        again = projects.first
        selection = [first, again]
        result = compensatr.sum_prices_for_group(selection, 'short_term')
        expect(result).to be_a(Float)
        expect(result).to eq 232.0
      end
    end
  end

  describe '#add_costs' do
    context 'with fake input' do
      it 'should return a hash with three keys and 1 as value per key' do
        allow(compensatr).to receive(:sum_prices_for_group).and_return(1)
        result = compensatr.add_costs(projects)
        expect(result).to be_a(Hash)
        expect(result).to include(short: 1, medium: 1, long: 1)
      end
    end

    context 'with proper input' do
      it 'should summarise prices in selection' do
        selection = [projects[0], projects[0],
          projects[1], projects[1],
          projects[2], projects[2]]
        result = compensatr.add_costs(selection)
        expect(result).to include(short: 464.0, medium:200.0, long:20.0)
      end
    end

    context 'with no input for a specific group' do
      it 'should return nil values for groups without representation in the selection' do
        selection = [projects.first]
        result = compensatr.add_costs(selection)
        expect(result).to include(short: 232.0, medium: nil, long: nil)
      end
    end
  end

  describe '#money_distribution' do
    context 'no values calculated' do
      it 'should return false' do
        result = compensatr.money_distribution(nil, 1,1)
        expect(result).to be false
      end
    end

    context 'no minimum value required for validation' do
      it 'should return true' do
        result = compensatr.money_distribution(1,1,0)
        expect(result).to be true
      end
    end

    context 'for standard inputs' do
      it 'should return true if the value is above the minimum money required for a group' do
        # 9 money units over a total of 10 money units spent
        # with a minimum expenditure required of 50%
        result = compensatr.money_distribution(9, 10, 50 )
        expect(result).to be true
      end

      it 'should return false if the value is below the minimum money required for a group' do
        # 1 money units over a total of 10 money units spent
        # with a minimum expenditure required of 50%
        result = compensatr.money_distribution(1, 10, 50 )
        expect(result).to be false
      end

      it 'should return true if the value matches the minimum money required for group' do
        result = compensatr.money_distribution(1, 10, 10)
        expect(result).to be true
      end
    end
  end

  describe '#validate_min_expenditures' do
    context 'for a fake input' do
      it 'should return a hash with all truthy values per group' do
        allow(compensatr).to receive(:money_distribution).and_return(true)
        groups = { min_short_term_percent: 1,
                   min_medium_term_percent: 1,
                   min_long_term_percent: 1 }
        # With this input, it should never pass, but the allow above fakes the validation
        expenditures = { short: 1, medium: 1, long: 1 }
        results = compensatr.validate_min_expenditures(expenditures, 1, groups)
        expect(results).to be_a(Hash)
        expect(results).to include(short: true, medium: true, long: true)
      end
    end

    context 'with legit input' do
      it 'should return a hash with all positives per group' do
        groups = { min_short_term_percent: 10,
                   min_medium_term_percent: 0,
                   min_long_term_percent: 0 }
        expenditure_per_group = { short: 1, medium: 1, long: 1 }
        total_expenditure = 3 # This gives a 33% distribution of the money per group
        results = compensatr.validate_min_expenditures(expenditure_per_group,
                                                       total_expenditure,
                                                       groups)
        expect(results).to be_a(Hash)
        expect(results).to include(short: true, medium: true, long: true)
      end

      it 'should return a hash with negative short term validation' do
        groups = { min_short_term_percent: 50,
                   min_medium_term_percent: 0,
                   min_long_term_percent: 0 }
        expenditure_per_group = { short: 1, medium: 1, long: 1 }
        total_expenditure = 3 # This gives a 33% distribution of the money per group
        results = compensatr.validate_min_expenditures(expenditure_per_group,
                                                       total_expenditure,
                                                       groups)
        expect(results).to be_a(Hash)
        expect(results).to include(short: false, medium: true, long: true)
      end
    end
  end

  describe '#remap_groups' do
    context 'with no minimum requirements per group' do
      it 'should return an empty hash' do
        groups = { min_short_term_percent: 0,
                   min_medium_term_percent: 0,
                   min_long_term_percent: 0 }
        remap = compensatr.remap_groups(groups)
        expect(remap).to be_a(Hash)
        expect(remap.empty?).to be true
      end
    end

    context 'with zero minimum required expenditure for short term projects' do
      it 'should return a hash with mapping for medium and long term projects only' do
        groups = { min_short_term_percent: 0,
                   min_medium_term_percent: 1,
                   min_long_term_percent: 1 }
        remap = compensatr.remap_groups(groups)
        expect(remap).to be_a(Hash)
        expect(remap).not_to include(0) # the key, not the value
      end
    end
  end

  describe '#valid_min_groups' do
    context 'without requirements of money distribution per group' do
      it 'should be valid' do
        groups = {}
        valid = compensatr.valid_min_groups([], groups)
        expect(valid).to be true
      end
    end

    context 'with legit input' do
      it 'should return true for a given selection with requirements on money distribution met' do
        groups = { min_short_term_percent: 2,
                   min_medium_term_percent: 2,
                   min_long_term_percent: 2 }
        money_spent = 342 # 100% of the money spent. See fixture for info on costs
        valid = compensatr.valid_min_groups(projects, groups)
        expect(valid).to be true
      end
    end
  end

  describe '#aggregate' do
    it 'should compact the selection and return an array with unique projects and count' do
      selection = [projects.first, projects.first]
      enriched_selection = compensatr.calculate_efficiency(selection)
      result = compensatr.aggregate(selection)
      expect(result).to be_a(Array)
      expect(result.count).to eq 1
      expect(result.first[:count]).to eq 2
    end

    it 'should show a count of 1 if the selection does not contain repeated projects' do
      selection = compensatr.calculate_efficiency(projects)
      result = compensatr.aggregate(selection)
      expect(result).to be_a(Array)
      expect(result.count).to eq 3
      expect(result.first[:count]).to eq 1
    end

    context 'given an empty array as input' do
      it 'should return an empty array as result' do
        result = compensatr.aggregate([])
        expect(result).to be_a(Array)
        expect(result.count).to eq 0
      end
      
    end
    
  end

  describe '#generate_purchase_plan' do
    context 'given a selection containing two times project with id p1' do
      let(:selection) { s = [projects.first, projects.first]
        compensatr.calculate_efficiency(s)
      }

      it 'should return an array of hashes' do
        result = compensatr.generate_purchase_plan(selection)
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Hash)
      end

      it 'should contain hashes with project_id, num_units and price' do
        result = compensatr.generate_purchase_plan(selection)
        # price is 232.0 * 2 = 464.0
        expect(result.first).to include('project_id' => "p1",
          'num_units' => 2,
          'price' => 464.0)
      end
    end

    context 'given an empty selection' do
      it 'should return an array of hashes without data' do
        stub_const('LOGGER', Logger.new(nil)) # ´cause there will be logs
        result = compensatr.generate_purchase_plan([])
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Hash)
        expect(result.first.empty?).to be true
      end
    end
  end

  describe '#years_to_report' do
    context 'when years are specified' do
      it 'should return an array with first element being current year' do
        result = compensatr.years_to_report(10)
        expect(result).to be_a(Array)
        expect(result.size).to eq 10
        expect(result.first).to eq(Date.today.year)
      end

      it 'should return an array with 1 element if report is requested for 1 year' do
        stub_const('LOGGER', Logger.new(nil))
        result = compensatr.years_to_report(1)
        expect(result).to be_a(Array)
        expect(result.size).to be 1
        expect(result.pop).to eq(Date.today.year)
      end

      it 'should return an empty array if report is requested for less than 1 year' do
        stub_const('LOGGER', Logger.new(nil))
        result = compensatr.years_to_report(0)
        expect(result).to be_a(Array)
        expect(result.empty?).to be true
      end
    end

    context 'when years are not specified' do
      it 'should return an empty array' do
        stub_const('LOGGER', Logger.new(nil))
        result = compensatr.years_to_report(nil)
        expect(result).to be_a(Array)
        expect(result.empty?).to be true
      end
    end
  end

  describe '#generate_co2_report' do
    context 'given an empty selection' do
      it 'should return an array of hashes without data' do
        stub_const('LOGGER', Logger.new(nil)) # ´cause there will be logs
        result = compensatr.generate_co2_report([], 1)
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Hash)
        expect(result.first.empty?).to be true
      end 
    end

    context 'given no years as input' do
      let(:selection) { s = [projects.first, projects.first]
        compensatr.calculate_efficiency(s)
      }
      it 'should return an array of hashes without data' do
        stub_const('LOGGER', Logger.new(nil)) # ´cause there will be logs
        result = compensatr.generate_co2_report(selection, nil)
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Hash)
        expect(result.first.empty?).to be true
      end
    end

    context 'given standard input' do
      let(:selection) { s = [projects.first, projects.first]
        compensatr.calculate_efficiency(s)
      }
      it 'should return an array of hashes with year and co2_captured data' do
        result = compensatr.generate_co2_report(selection, 1)
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Hash)
        expect(result.first).to include('year' => 2020, 'co2_captured' => 363.6)
      end
    end
  end
end
