require 'spec_helper'
require 'command'
require 'command/piped'

RSpec.describe Command::Piped do
  it 'runs commands in sequence' do
    called = []
    a = command(:A) { called << :A }
    b = command(:B) { called << :B }
    c = command(:C) { called << :C }

    result = (a | b | c).call

    expect(called).to eq(%i[A B C])
    expect(result).to be_success
  end

  it 'aborts on a failure' do
    called = []
    a = command(:A) { called << :A }
    b = command(:B) { called << :B; err! :bang }
    c = command(:C) { called << :C }

    result = (a | b | c).call

    expect(called).to eq(%i[A B])
    expect(result).to be_failure
    expect(result.code).to eq(:bang)
  end

  it 'acts as a result switch' do
    a = command(:A) { nil }
    b = command(:B) { nil }
    c = command(:C) { nil }

    called = false
    (a | b | c).call do
      ok do
        called = true
      end
      any { raise "not called" }
    end

    expect(called).to eq(true)
  end

  it 'handles failures from any branch in the result switch' do
    a = command(:A) { nil }
    b = command(:B) { err!(:from_b) }
    c = command(:C) { nil }

    called = false
    (a | b | c).call do
      error(:from_b) do
        called = true
      end
      any { raise "not called" }
    end

    expect(called).to eq(true)
  end

  private def command(name, &block)
    Class.new do
      include Command
      def initialize(**params); end
      define_method(:inspect) { "#<Command #{name}>"}
      define_method(:call, &block)
    end.new
  end
end
