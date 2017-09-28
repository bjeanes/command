require 'spec_helper'

RSpec.describe Command::Result do
  describe Command::Success do
    it 'is a Result' do
      expect(Command::Success.new).to be_a Command::Result
    end

    it 'is a success' do
      expect(Command::Success.new).to be_success
    end

    it 'is not a failure' do
      expect(Command::Success.new).to_not be_failure
    end

    it 'can have no value' do
      expect(Command::Success.new.value).to be_nil
    end

    it 'has a value' do
      expect(Command::Success.new(42).value).to eq 42
    end

    it 'is mappable' do
      result = Command::Success.new(42)
      expect { |b| result.map(&b) }.to yield_with_args(42)
    end
  end

  describe Command::Failure do
    it 'is a failure' do
      expect(Command::Failure.new).to be_failure
    end

    it 'is not a success' do
      expect(Command::Failure.new).to_not be_success
    end

    it 'has a default payload' do
      expect(Command::Failure.new.payload).to eq({})
    end

    it 'has a custom payload' do
      expect(Command::Failure.new(payload: 42).payload).to eq 42
    end

    it 'is does nothing when being mapped' do
      result = Command::Failure.new(payload: 42)
      expect { |b| result.map(&b) }.not_to yield_control
    end

    it 'raises itself if trying to access the result value' do
      result = Command::Failure.new
      expect { result.value }.to raise_error(result)
    end

    it 'has a default error code' do
      expect(Command::Failure.new.code).to eq :error
    end

    it 'has an error code' do
      expect(Command::Failure.new(code: :foo).code).to eq :foo
    end

    it 'accepts a custom message' do
      expect(Command::Failure.new(message: 'xyz').message).to eq 'xyz'
    end

    it 'looks up error messages based on code' do
      code = :some_error_message
      i18n = class_double(I18n)

      allow(i18n).to receive(:translate).with(code, {locale: :en, scope: [:errors], default: "Some error message"}) do
        "My error message"
      end

      expect(Command::Failure.new(code: code, i18n: i18n).message).
        to eq "My error message"
    end

    it 'interpolates payload in custom messages' do
      i18n = class_double(I18n)
      payload = {foo: 1, bar: 2}
      expect(i18n).to receive(:translate).with(anything, hash_including(payload))
      Command::Failure.new(payload: payload, i18n: i18n).message
    end
  end
end

