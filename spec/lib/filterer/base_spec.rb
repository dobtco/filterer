require 'spec_helper'

class FakeQuery
  COUNT = 5

  def method_missing(method, *args)
    self
  end

  def count(*args); COUNT end;
end

class DefaultFilterer < Filterer::Base; end;

class SmokeTestFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end
end

describe Filterer::Base do

  it 'warns if starting_query is not overriden' do
    expect { DefaultFilterer.new }.to raise_error('You must override this method!')
  end

  it 'basic smoke test' do
    FakeQuery.any_instance.should_receive(:limit).with(10).and_return(FakeQuery.new)
    FakeQuery.any_instance.should_receive(:offset).with(0).and_return(FakeQuery.new)

    @filterer = SmokeTestFilterer.new
    @filterer.meta[:page].should == 1
    @filterer.meta[:last_page].should == 1
    @filterer.meta[:total].should == FakeQuery::COUNT
  end

  it 'passes parameters to the correct methods' do
    SmokeTestFilterer.any_instance.should_receive(:param_foo).with('bar').and_return(FakeQuery.new)
    @filterer = SmokeTestFilterer.new({ foo: 'bar' })
  end

  it 'does not pass the :page parameter' do
    SmokeTestFilterer.any_instance.should_not_receive(:param_page)
    @filterer = SmokeTestFilterer.new({ page: 'bar' })
  end

  it 'does not pass blank parameters' do
    SmokeTestFilterer.any_instance.should_not_receive(:param_foo)
    @filterer = SmokeTestFilterer.new({ foo: '' })
  end

end
