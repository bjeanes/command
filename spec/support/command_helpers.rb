require 'rspec/expectations'

module CommandHelpers
  extend RSpec::Matchers::DSL

  matcher :have_failed do
    match do |result|
      result.failure? &&
        result.code == (code || result.code) &&
        result.payload == (payload || result.payload)
    end
    chain :as, :code
    chain :with, :payload
  end

  matcher :have_succeeded do
    match { |result| result.success? }
  end
end
