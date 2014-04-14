require 'spec_helper'

class FakeQuery
  COUNT = 5

  def method_missing(method, *args)
    self
  end

  def count(*args); COUNT end;
end

class DefaultFilterer < Filterer::Base; end;

class UnscopedFilterer < Filterer::Base
  def starting_query
    Person.select('name, email')
  end
end

class SmokeTestFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end
end

class SortingFiltererA < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  sort_option 'id', default: true
end

class InheritedSortingFiltererA < SortingFiltererA
end

class SortingFiltererB < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  sort_option 'id', default: true
  sort_option 'thetiebreaker', tiebreaker: true
end

class SortingFiltererC < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  sort_option 'id', default: true
  sort_option Regexp.new('foo([0-9]+)'), -> (results, matches, filterer) { results.order(matches[1] + ' ' + filterer.direction) }
end

class SortingFiltererD < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  sort_option 'foo', 'baz', nulls_last: true
end

class SortingFiltererE < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  sort_option 'id', default: true
  sort_option Regexp.new('foo([0-9]+)'), -> (results, matches, filterer) { results.order(matches[1] + ' ' + filterer.direction) }
  sort_option Regexp.new('zoo([0-9]+)'), -> (results, matches, filterer) { results.order('zoo') }
end

class PaginationFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end
end

class PaginationFiltererB < PaginationFilterer
  per_page 30
end

class PaginationFiltererWithOverride < PaginationFilterer
  per_page 20, allow_override: true
end

class PaginationFiltererInherit < PaginationFiltererB
end

describe Filterer::Base do

  it 'warns if starting_query is not overriden' do
    expect { DefaultFilterer.new }.to raise_error('You must override this method!')
  end

  it 'allows start query in the opts hash' do
    expect {
      DefaultFilterer.new({}, starting_query: Person.select('name, email'))
    }.to_not raise_error
  end

  it 'basic smoke test' do
    SmokeTestFilterer.any_instance.should_receive(:starting_query).and_return(f = FakeQuery.new)
    SmokeTestFilterer.any_instance.should_receive(:respond_to?).with(:custom_meta_data).and_return(false)
    f.should_receive(:limit).with(20).and_return(f)
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
    higher_count = 35

    SmokeTestFilterer.any_instance.should_receive(:starting_query).and_return(f = FakeQuery.new)
    f.should_receive(:limit).with(20).and_return(f)
    f.should_receive(:offset).with(20).and_return(f)
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

  describe 'sorting' do
    it 'does not sort by default' do
      filterer = SmokeTestFilterer.new
      filterer.sort.should be_nil
    end

    it 'can apply a default sort' do
      filterer = SortingFiltererA.new
      filterer.sort.should == 'id'
    end

    it 'can apply a default sort when inheriting a class' do
      filterer = InheritedSortingFiltererA.new
      filterer.sort.should == 'id'
    end

    it 'can include a tiebreaker' do
      FakeQuery.any_instance.should_receive(:order).with(/thetiebreaker/).and_return(FakeQuery.new)
      filterer = SortingFiltererB.new
      filterer.sort.should == 'id'
    end

    it 'can match by regexp' do
      filterer = SortingFiltererC.new(sort: 'foo111')
      filterer.sort.should == 'foo111'
    end

    it 'does not choke on a nil param' do
      filterer = SortingFiltererC.new
      filterer.sort.should == 'id'
    end

    it 'can apply a proc' do
      FakeQuery.any_instance.should_receive(:order).with('111 ASC').and_return(FakeQuery.new)
      filterer = SortingFiltererC.new(sort: 'foo111')
      filterer.sort.should == 'foo111'
    end

    it 'can put nulls last' do
      FakeQuery.any_instance.should_receive(:order).with('baz ASC NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo')
    end

    it 'can change to desc' do
      FakeQuery.any_instance.should_receive(:order).with('baz DESC NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo', direction: 'desc')
    end

    it 'can distinguish between two regexps' do
      FakeQuery.any_instance.should_receive(:order).with('zoo').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'zoo111')
      filterer.sort.should == 'zoo111'
    end

    it 'can distinguish between two regexps part 2' do
      FakeQuery.any_instance.should_receive(:order).with('111 ASC').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'foo111')
      filterer.sort.should == 'foo111'
    end

    it 'throws an error when key is a regexp and no query string given' do
      expect {
        class ErrorSortingFiltererA < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option Regexp.new('hi')
        end
      }.to raise_error
    end

    it 'throws an error when key is a regexp and it is the default key' do
      expect {
        class ErrorSortingFiltererB < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option Regexp.new('hi'), 'afdsfasdf', default: true
        end
      }.to raise_error
    end

    it 'throws an error when option is a tiebreaker and it has a proc' do
      expect {
        class ErrorSortingFiltererC < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option 'whoop', -> (q, matches) { q }, tiebreaker: true
        end
      }.to raise_error
    end
  end

  describe 'pagination' do
    describe 'per_page' do
      it 'defaults to 20' do
        @filterer = PaginationFilterer.new
        @filterer.meta[:per_page].should == 20
      end

      it 'can be set to another value' do
        @filterer = PaginationFiltererB.new
        @filterer.meta[:per_page].should == 30
      end

      it 'inherits when subclassing' do
        @filterer = PaginationFiltererInherit.new
        @filterer.meta[:per_page].should == 30
      end

      it 'can be overriden' do
        @filterer = PaginationFiltererWithOverride.new
        @filterer.meta[:per_page].should == 20
        @filterer = PaginationFiltererWithOverride.new(per_page: 15)
        @filterer.meta[:per_page].should == 15
      end
    end
  end

  describe 'unscoping' do
    it 'unscopes select' do
      @filterer = UnscopedFilterer.new
      @filterer.meta[:total].should == 0
    end
  end

end
