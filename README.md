# compensatr

Compensatr is a tool to calculate efficient CO2 compensation projects given 
specific JSON input and parameters.

## The problem

The problem can be found in Github under [Compensate-operations/compensate-challenge](https://github.com/Compensate-Operations/compensate-challenge)
It is reproduced here under [CHALLENGE.md](CHALLENGE.md), copied verbatim at [7769135](https://github.com/Compensate-Operations/compensate-challenge/commit/776913552a682f2797a9779263b6ef95b70fee2b)

## The solution

The solution proposed is a small script that searches for a selection of projects that meet the requirements and the additional input parameters specified by the user.

The search is performed by "brute forcing" a set of projects that match the above mentioned criteria. After setup the requirements input by the user and calculating the yearly CO2 "capture potential" for each project the script loops over the source data finding the best matching set of projects that capture the most CO and meet the user input requirements for money distribution and allocation.

### Included

- The main script, which entry point is `init.rb`.
- Unit tests under `./spec`.
- Data samples under `./data`.
- Unit test coverage. Can be seen opening `./spec/coverage/index.html` in a web browser.

## The rationales behind the solution

- The solution is suboptimal...for now. The explanation for this is well captured by [Kent Beck](https://en.wikipedia.org/wiki/Kent_Beck)'s famous quote: *"Make it work, make it right, make it fast"*. For improvements see[Proposed improvements](#proposed-improvements).

- The solution is **coded in pure Ruby**. Ruby is not the fastest on the bunch, but is great for transmitting and shaping raw ideas into a script (flexibility and developer comfort before performance, for this specific task).

- The script focuses on engineering best practices (use of automated coding style guidelines, unit testing, etc), while remaining as what it is in the end: a small proof of concept.

- Calculating CO2 captured is tricky. When generating the CO2 report once the most performant selection of projects has been found, a decision was made to calculate the CO2 captured the following way:
  For each year that the report is requested, the script figures out which projects are still "active" for the given year. This is based in the assumption that, if a project has a `time` of e.g.: 2 years to complete capturing the CO2 stated as `co2_volume`, the report should count `yearly_co2_vol` for the first 2 years since the report is requested. After that it is assumed _the project "has finished" and the CO2 captured should not be reported_. See the implementation for more details.


## Setup and usage

### Ruby on Mac OS X

For the sake of simplicity, the instructions below apply to a setup under Mac OS X, YMMV.

1. It is recommended to install latest [RVM (Ruby Version Manager)](https://rvm.io/).
2. Install latest Ruby 2.6. With RVM:
```
$ rvm install ruby-2.6.5
```
3. Checkout code from Github:
```
$ git clone git@github.com:magandrez/compensatr.git .
```
4. cd into ./compensatr should trigger RVM to up the specific gemset
```
$ cd compensatr
ruby-2.6.5 - #gemset created /Users/spav/.rvm/gems/ruby-2.6.5@compensatr
ruby-2.6.5 - #generating compensatr wrappers - please wait
```
5. The solution is coded in pure Ruby, no additional gems are needed (for running the script). 
  Run the script following the script's help for information on the input parameters. 
  A sample dataset is provided under `./compensatr/data/sample.json`:
```
$ ruby init.rb --help
Usage: compensatr.rb -f <path> -m <value> [options]
Options:
    -f, --file <path>                Source file of projects
    -t, --target <path>              Target file where result is stored. Defaults to ./data/output.json
    -m, --money <value>              Amount of money to be used
        --target_years <value>       Target years for C02 optimization, defaults to 1
        --min_continents <value>     Minimum number of continents where projects should be distributed, defaults to 1
        --min_short_term_percent <value>
                                     Minimum percentage of short term projects to be bought, defaults to 0
        --min_medium_term_percent <value>
                                     Minimum percentage of medium term projects to be bought, defaults to 0
        --min_long_term_percent <value>
                                     Minimum percentage of long term projects to be bought, defaults to 0
    -v, --[no-]verbose               Run verbosely
    -h, --help                       Show options
```
### Docker

TODO

## Proposed improvements

1. **Additional compensation round**. As stated in the solution description, the script loops over the dataset provided finding the most suitable suitable set of projects that meet the requirements. 
  A perfect solution is not always achieved due to the inherent approach based on finding suitable combinations over a large dataset. The different possible solutions are potentially very large, depending on a number of factors (dataset size, constraints imposed, number of iterations, etc.). Because of this, the script does not always consume 100% of the money allocated for the run, leaving marginal quantities of money left depending on the run. 
  To fix this, **it is possible to improve the algorithm to use up all the allocated money after a suitable selection is found and the main loop ends iterating**; this is a proposed improvement, althoug it is relatively simple to implement, it was decided to leave it as an improvement since it is based on the same pattern as the main solution, and does no add any extra value to this proof of concept.

2. **Stronger data input validation**. The data validation performed by this solution is rather minimal, since it was not deemed to be the core problem to solve for this proof-of-concept.

3. **Provide control over the script defaults constants**. Defaults could be transformed into environment variables for ease of use. Seemingly, allowing users to set the maximum number of iterations for the script to perform adds flexibility when/if running over large datasets 

4. **Complete unit test coverage**.

5. **Dockerize solution**.
 

## Caveats

- Script performance takes a hit depending on dataset size and maximum number of iterations set.

## Development

Install gemset using bundler

```
$ bundle install
```
Run [Rubocop](https://github.com/rubocop-hq/rubocop) static code analyzer:
```
$ bundle exec rubocop
```
Test coverage provided by [Simplecov](https://github.com/colszowka/simplecov) is generated upon running test suite.

Running specs with rspec
```
$ bundle exec rspec
```

## License

See [LICENSE.md](LICENSE.md)
