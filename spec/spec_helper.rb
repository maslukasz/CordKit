# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
end

require "cordkit"
require "webmock/rspec"

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |file| require file }

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.example_status_persistence_file_path = "tmp/rspec_status.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
