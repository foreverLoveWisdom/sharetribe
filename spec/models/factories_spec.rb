require "spec_helper"

# See https://github.com/thoughtbot/factory_bot/wiki/Testing-all-Factories-(with-RSpec)

describe "Factory Girl", type: :model do

  # List here factories that should be ignored.
  # E.g. :payment is ignored, since it's a super class and shouldn't be instantiated
  ignored_factories = [
    :payment
  ]

  (FactoryBot.factories.map(&:name) - ignored_factories).each do |factory_name|
    describe "#{factory_name} factory" do


      it "is valid" do
        factory = FactoryBot.build(factory_name)
        if factory.respond_to?(:valid?)
          factory.valid?

          expect(factory).to be_valid, error_message(factory)
        end
      end
    end
  end

  def error_message(factory)
    result = factory.errors.messages.map do |(field_name, errors)|
      ":#{field_name} => #{errors.join(', ')}"
    end
    ([factory.class.name.to_s] + result).join("\n")
  end
end
