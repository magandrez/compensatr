# frozen_string_literal: true

require_relative 'compensatr'
require 'logger'

LOGGER = Logger.new($stdout)
LOGGER.level = Logger::INFO

Compensatr.new.run
