require 'spec_helper'

RSpec.describe Command do
  describe 'subclasses' do
    context 'called directly' do
      it 'returns a successful result' do
        result = command { 42 }.call
        aggregate_failures do
          expect(result).to be_a Command::Result
          expect(result).to be_a Command::Success
          expect(result).to be_success
          expect(result.value).to eq 42
        end
      end

      it 'returns a generic failure result' do
        result = command { err! }.call
        aggregate_failures do
          expect(result).to be_a Command::Result
          expect(result).to be_a Command::Failure
          expect(result).to be_failure
          expect { result.value }.to raise_error(result)
          expect(result.payload).to be_nil
          expect(result.code).to eq :error
        end
      end

      it 'returns a named failure result' do
        result = command { err! :validation_failed }.call
        aggregate_failures do
          expect(result).to be_a Command::Result
          expect(result).to be_a Command::Failure
          expect(result).to be_failure
          expect { result.value }.to raise_error(result)
          expect(result.payload).to be_nil
          expect(result.code).to eq :validation_failed
        end
      end

      it 'returns a named failure result with a value' do
        result = command { err! :validation_failed, ["error1", "error2"] }.call
        aggregate_failures do
          expect(result).to be_a Command::Result
          expect(result).to be_a Command::Failure
          expect(result).to be_failure
          expect(result.payload).to eq ["error1", "error2"]
          expect(result.code).to eq :validation_failed
        end
      end

      it 'raises on exception' do
        cmd = command { raise ArgumentError, "Missing :foo" }
        expect { cmd.call }.to raise_error(ArgumentError, "Missing :foo")
      end

      it 'rolls back transactions on error' do
        cmd = command do
          transaction do
            Plan.create!(name: SecureRandom.hex, price_cents: 0, number_of_reviews: 0)
            err!
          end
        end

        expect { cmd.call }.not_to change { Plan.count }
      end

      it 'allows rolling back inner transactions' do
        plan = nil
        cmd = command do
          transaction do
            plan = Plan.create!(name: SecureRandom.hex, price_cents: 0, number_of_reviews: 0)
            transaction do
              plan.update_column(:price_cents, 9001)
              raise ActiveRecord::Rollback
            end
          end
        end

        expect { cmd.call }.to change { Plan.count }
        expect(plan.reload.price).to eq 0
      end

      it 'returns actual return value if it is a Command::Result' do
        result = Command::Success.new(42)
        cmd = command { result }

        expect(cmd.call).to equal(result)
      end
    end

    context 'called with switch block' do
      it 'handles a successful result with :ok switch' do
        cmd = command { 42 }
        yielded = nil
        cmd.call do
          error { fail "error handler called when it shouldn't have been" }
          ok do |result|
            yielded = result
          end
        end
        expect(yielded).to eq 42
      end

      it 'allows setting ivars in handler' do
        cmd = command { 42 }
        cmd.call do
          ok do |result|
            @yielded = result
          end
        end
        expect(@yielded).to eq 42
      end

      it 'raises ArgumentError if no successful result handler is defined for a successful result' do
        cmd = command { 42 }
        expect {
          cmd.call do
            error(:foobar) {}
          end
        }.to raise_error(ArgumentError, 'No success handler or fallback defined')
      end

      it 'handles named error' do
        cmd = command { err! :validation_failed, ["error1", "error2"] }
        errors = nil
        cmd.call do
          ok { raise "success handler called when it shouldn't have been" }
          error(:validation_failed) { |e| errors = e }
        end
        expect(errors).to eq ["error1", "error2"]
      end

      it 'handles exceptions generically' do
        cmd = command { raise ArgumentError, "Missing :foo" }
        exception = nil
        cmd.call do
          exception { |e| exception = e }
        end

        expect(exception).to be_a ArgumentError
      end

      it 'handles exceptions by class' do
        cmd = command { raise ArgumentError, "Missing :foo" }
        exception = nil
        cmd.call do
          exception(ArgumentError) { |e| exception = e }
          exception { |e| raise "I should not be caused" }
        end

        expect(exception).to be_a ArgumentError
      end

      it 'handles exceptions by ancestor' do
        cmd = command { raise ArgumentError, "Missing :foo"}
        exception = nil
        cmd.call do
          exception(StandardError) { |e| exception = e }
          exception(Exception) { fail "exception ancestor handler called when more specific one exists" }
        end

        expect(exception).to be_a ArgumentError
      end

      it 're-raises unhandled exception' do
        cmd = command { raise ArgumentError, "Missing :foo"}
        expect {
          cmd.call do
            ok { } # No exception handler
          end
        }.to raise_error(ArgumentError, "Missing :foo")
      end
    end
  end

  def command(&block)
    Class.new do
      include Command
      def initialize(**params); end
      define_method(:call, &block)
    end
  end
end
