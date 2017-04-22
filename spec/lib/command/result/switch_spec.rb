require 'spec_helper'

RSpec.describe Command::Result::Switch do
  it 'errors without a block' do
    expect { described_class.new }.to raise_error(ArgumentError, 'block required')
  end

  it 'raises error if block not passed to handlers' do
    aggregate_failures do
      expect { described_class.new { ok } }.to raise_error(ArgumentError, 'No block given')
      expect { described_class.new { error } }.to raise_error(ArgumentError, 'No block given')
      expect { described_class.new { error(:boom!) } }.to raise_error(ArgumentError, 'No block given')
      expect { described_class.new { exception } }.to raise_error(ArgumentError, 'No block given')
      expect { described_class.new { exception(RuntimeError) } }.to raise_error(ArgumentError, 'No block given')
      expect { described_class.new { any } }.to raise_error(ArgumentError, 'No block given')
    end
  end

  it 'errors if no handlers defined' do
    expect { described_class.new { } }.to raise_error(ArgumentError, 'No handlers defined')
  end

  describe 'handler scope' do
    let(:result) { Command::Success.new }

    def method_on_caller
      @called = true
    end

    it "has access to call methods from the caller" do
      switch { ok { method_on_caller }}
      expect(@called).to be true
    end

    it "has access to caller's instance variables" do
      switch { ok { @called = true }}
      expect(@called).to be true
    end
  end

  context 'with successful result' do
    let(:result) { Command::Success.new(42) }

    it 'calls the OK block with its value' do
      expect do |b|
        switch do
          ok(&b)
          any { fail "fallback incorrectly invoked" }
        end
      end.to yield_with_args(result.value)
    end

    it 'calls the fallback with result' do
      expect do |b|
        switch { any(&b) }
      end.to yield_with_args(result)
    end

    it 'raises if no OK handler or fallback is defined' do
      expect do
        switch do
          error { } # handlers defined, but not OK or fallback
        end
      end.to raise_error(ArgumentError, 'No success handler or fallback defined')
    end
  end

  context 'with failure result' do
    let(:result) { Command::Failure.new(code: :boom!) }

    it 'calls the general error block on failure with default error code and empty payload' do
      expect do |b|
        switch(Command::Failure.new) do
          error(&b)
          any { fail "fallback incorrectly invoked" }
        end
      end.to yield_with_args(:error, {})
    end

    it 'passes error code and payload to general error block' do
      expect do |b|
        switch(Command::Failure.new(code: :boom!, payload: {a: 42})) do
          error(&b)
          any { fail "fallback incorrectly invoked" }
        end
      end.to yield_with_args(:boom!, {a: 42})
    end

    it 'calls the specific error block on failure' do
      expect do |b|
        switch do
          error(:boom!, &b)
          error { fail "general error handler invoked" }
          any { fail "fallback incorrectly invoked" }
        end
      end.to yield_control
    end

    it 'passes payload to specific error block' do
      expect do |b|
        switch(Command::Failure.new(code: :boom!, payload: {a: 42})) do
          error(:boom!, &b)
          error { fail "general error handler invoked" }
          any { fail "fallback incorrectly invoked" }
        end
      end.to yield_with_args({a: 42})
    end

    it 'calls the fallback with result' do
      expect do |b|
        switch { any(&b) }
      end.to yield_with_args(result)
    end

    it 'raises if no error handlers or fallback is defined' do
      expect do
        switch do
          ok { } # handlers defined, but not errors or fallback
        end
      end.to raise_error(ArgumentError, 'No failure handler or fallback defined')
    end
  end

  context 'with exception result' do
    let(:exception_class) { Class.new(RuntimeError) }
    let(:exception) { exception_class.new('error') }
    let(:result) { Command::Failure.new(code: :exception, cause: exception)}

    it 'calls the general exception handler with exception' do
      expect do |b|
        switch { exception(&b) }
      end.to yield_with_args(exception)
    end

    it 'calls the specific exception handler with exception' do
      klass = exception_class
      expect do |b|
        switch do
          exception { fail "general exception handler invoked" }
          exception(klass, &b)
        end
      end.to yield_with_args(exception)
    end

    it 'calls an ancestor exception handler with exception' do
      expect do |b|
        switch do
          exception { fail "general exception handler invoked" }
          exception(StandardError) { fail "too general exception ancestor handler invoked" }
          exception(RuntimeError, &b)
        end
      end.to yield_with_args(exception)
    end

    it 'does not call the fallback handler' do
      expect do |b|
        begin
          switch do
            any(&b)
          end
        rescue
        end
      end.not_to yield_control
    end

    it 'does not call the error handler' do
      expect do |b|
        begin
          switch do
            error(&b)
          end
        rescue
        end
      end.not_to yield_control
    end

    it 're-raises the original error if handler not defined' do
      expect do
        switch do
          # handlers defined, just not exception handlers
          ok { }
          error { }
        end
      end.to raise_error(exception)
    end
  end

  private

  def switch(result = self.result, &block)
    described_class.new(&block).call(result)
  end
end
