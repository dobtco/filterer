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
    SmokeTestFilterer.any_instance.should_receive(:starting_query).and_return(f = FakeQuery.new)
    SmokeTestFilterer.any_instance.should_receive(:respond_to?).with(:custom_meta_data).and_return(false)
    f.should_receive(:limit).with(10).and_return(f)
    f.should_receive(:offset).with(0).and_return(f)

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

  it 'has a paginator' do
    @filterer = SmokeTestFilterer.new({ foo: '' })
    @filterer.paginator.should be_a(Filterer::Paginator)
  end

  it 'calculates more complex page numbers and totals' do
    higher_count = 15

    SmokeTestFilterer.any_instance.should_receive(:starting_query).and_return(f = FakeQuery.new)
    f.should_receive(:limit).with(10).and_return(f)
    f.should_receive(:offset).with(10).and_return(f)
    stub_const("FakeQuery::COUNT", higher_count)

    @filterer = SmokeTestFilterer.new({ page: 2 }, { })
    @filterer.meta[:page].should == 2
    @filterer.meta[:last_page].should == 2
    @filterer.meta[:total].should == higher_count
  end

  it 'can count without all the other stuff' do
    FakeQuery.any_instance.should_not_receive(:limit)
    SmokeTestFilterer.any_instance.should_receive(:param_foo).with('bar').and_return(FakeQuery.new)
    SmokeTestFilterer.count({ foo: 'bar' }).should == FakeQuery::COUNT
  end

  it 'can add custom meta data' do
    SmokeTestFilterer.any_instance.stub(:custom_meta_data).and_return({ bar: 'baz' })
    @filterer = SmokeTestFilterer.new
    @filterer.meta[:bar].should == 'baz'
  end

end
