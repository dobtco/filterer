require 'spec_helper'

class FakeQuery
  COUNT = 5

  def method_missing(method, *args)
    self
  end

  def to_str
    'FakeQuery'
  end

  def to_ary
    ['FakeQuery']
  end

  def count(*args); COUNT end;
end

class DefaultFilterer < Filterer::Base; end;

class MutationFilterer < Filterer::Base
  def starting_query
    # This would really be doing it wrong...
    params[:foo] = 'bar'

    FakeQuery.new
  end
end

class DefaultParamsFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  def defaults
    {
      foo: 'bar'
    }
  end
end

class DefaultFiltersFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end

  def apply_default_filters
    if opts[:foo]
      results.where(foo: 'bar')
    end
  end
end

class ReturnNilFilterer < Filterer::Base
  def starting_query
    Person.all
  end

  def param_foo(x)
    # nil
  end
end

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
  sort_option Regexp.new('foo([0-9]+)'), -> (matches) { matches[1] }
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

  def something_important
    'yeehaw'
  end

  sort_option 'id', default: true
  sort_option Regexp.new('foo([0-9]+)'), -> (matches) { matches[1] }
  sort_option Regexp.new('zoo([0-9]+)'), -> (matches) {
    if matches[1].to_i > 10
      'zoo'
    end
  }
  sort_option 'context', -> (_matches) {
    something_important
  }
end

class SortingFiltererF < SortingFiltererE
  sort_option 'tiebreak', tiebreaker: true
end

class PaginationFilterer < Filterer::Base
  def starting_query
    FakeQuery.new
  end
end

class PaginationFiltererB < PaginationFilterer
  self.per_page = 30
end

class PaginationFiltererWithOverride < PaginationFilterer
  self.per_page = 20
  self.allow_per_page_override = true
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

  it 'does not mutate the params hash' do
    params = {}
    filterer = MutationFilterer.new(params)
    expect(params).to eq({})
  end

  it 'adds default params' do
    filterer = DefaultParamsFilterer.new({})
    expect(filterer.params).to eq('foo' => 'bar')
  end

  it 'applies default filters' do
    expect_any_instance_of(FakeQuery).to receive(:where).with(foo: 'bar').and_return(FakeQuery.new)
    filterer = DefaultFiltersFilterer.filter({}, foo: 'bar')
  end

  it 'allows returning nil from default filters' do
    expect_any_instance_of(FakeQuery).to receive(:where).with(bar: 'baz').and_return(FakeQuery.new)
    filterer = DefaultFiltersFilterer.filter({}).where(bar: 'baz')
  end

  it 'passes parameters to the correct methods' do
    expect_any_instance_of(SmokeTestFilterer).to receive(:param_foo).with('bar').and_return(FakeQuery.new)
    SmokeTestFilterer.filter(foo: 'bar')
  end

  it 'does not pass blank parameters' do
    expect_any_instance_of(SmokeTestFilterer).not_to receive(:param_foo)
    SmokeTestFilterer.new(foo: '')
  end

  it 'allows returning nil from a param_* method' do
    expect(ReturnNilFilterer.filter(foo: 'bar')).to eq([])
  end

  describe 'sorting' do
    it 'orders by ID by default' do
      allow_any_instance_of(FakeQuery).to(
        receive_message_chain(:model, :table_name).
          and_return('asdf')
      )

      expect_any_instance_of(FakeQuery).to receive(:order).
        with('asdf.id asc').
        and_return(FakeQuery.new)

      filterer = SmokeTestFilterer.new
      expect(filterer.sort).to eq 'default'
    end

    it 'applies a default sort' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('id asc').and_return(FakeQuery.new)
      filterer = SortingFiltererA.new
      expect(filterer.sort).to eq 'id'
    end

    it 'applies a default sort when inheriting a class' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('id asc').and_return(FakeQuery.new)
      filterer = InheritedSortingFiltererA.new
      expect(filterer.sort).to eq 'id'
    end

    it 'can include a tiebreaker' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('id asc , thetiebreaker').and_return(FakeQuery.new)
      filterer = SortingFiltererB.new
    end

    it 'can match by regexp' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('111 asc').and_return(FakeQuery.new)
      filterer = SortingFiltererC.new(sort: 'foo111')
      expect(filterer.sort).to eq 'foo111'
    end

    it 'does not choke on a nil param' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('id asc').and_return(FakeQuery.new)
      filterer = SortingFiltererC.new
    end

    it 'can apply a proc' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('111 asc').and_return(FakeQuery.new)
      filterer = SortingFiltererC.new(sort: 'foo111')
    end

    it 'can put nulls last' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('baz asc NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo')
    end

    it 'can change to desc' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('baz desc NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo', direction: 'desc')
    end

    it 'can distinguish between two regexps' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('zoo asc').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'zoo111')
    end

    it 'still applies the tiebreaker' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('zoo asc , tiebreak').and_return(FakeQuery.new)
      filterer = SortingFiltererF.new(sort: 'zoo111')
    end

    it 'calls with context' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('yeehaw asc , tiebreak').and_return(FakeQuery.new)
      filterer = SortingFiltererF.new(sort: 'context')
    end

    it 'applies the default sort if the proc returns nil' do
      allow_any_instance_of(FakeQuery).to(
        receive_message_chain(:model, :table_name).
          and_return('asdf')
      )
      expect_any_instance_of(FakeQuery).to receive(:order).with('asdf.id asc').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'zoo1')
    end

    it 'can distinguish between two regexps part 2' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('111 asc').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'foo111')
    end

    it 'throws an error when key is a regexp and no query string given' do
      expect {
        class ErrorSortingFiltererA < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option Regexp.new('hi')
        end
      }.to raise_error(/provide a query string or a proc/)
    end

    it 'throws an error when key is a regexp and it is the default key' do
      expect {
        class ErrorSortingFiltererB < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option Regexp.new('hi'), 'afdsfasdf', default: true
        end
      }.to raise_error(/Default sort option can't have a Regexp key/)
    end

    it 'throws an error when option is a tiebreaker and it has a proc' do
      expect {
        class ErrorSortingFiltererC < Filterer::Base
          def starting_query
            FakeQuery.new
          end

          sort_option 'whoop', -> (matches) { nil }, tiebreaker: true
        end
      }.to raise_error(/Tiebreaker can't be a proc/)
    end
  end

  describe 'pagination' do
    describe 'per_page' do
      it 'defaults to 20' do
        filterer = PaginationFilterer.new
        expect(filterer.send(:per_page)).to eq(20)
      end

      it 'can be set to another value' do
        filterer = PaginationFiltererB.new
        expect(filterer.send(:per_page)).to eq(30)
      end

      it 'inherits when subclassing' do
        filterer = PaginationFiltererInherit.new
        expect(filterer.send(:per_page)).to eq(30)
      end

      it 'can be overriden' do
        filterer = PaginationFiltererWithOverride.new
        expect(filterer.send(:per_page)).to eq(20)
        filterer = PaginationFiltererWithOverride.new(per_page: '15')
        expect(filterer.send(:per_page)).to eq(15)
      end

      it 'can not be overriden past max' do
        filterer = PaginationFiltererWithOverride.new(per_page: 100000)
        expect(filterer.send(:per_page)).to eq(1000)
      end
    end
  end

  it 'allows accessing the filterer object' do
    results = UnscopedFilterer.filter
    expect(results.filterer).to be_a(Filterer::Base)
  end

  describe 'unscoping' do
    it 'unscopes select' do
      results = UnscopedFilterer.filter

      if defined?(Kaminari)
        expect(results.total_count).to eq(0)
      else
        expect(results.total_entries).to eq(0)
      end
    end
  end

  describe 'options' do
    it 'skips ordering' do
      expect_any_instance_of(DefaultParamsFilterer).to_not receive(:ordered_results)
      filterer = DefaultParamsFilterer.filter({}, skip_ordering: true)
    end

    it 'skips pagination' do
      expect_any_instance_of(DefaultParamsFilterer).to_not receive(:paginate_results)
      filterer = DefaultParamsFilterer.filter({}, skip_pagination: true)
    end

    it 'provides a helper method to skip both' do
      expect_any_instance_of(DefaultParamsFilterer).to_not receive(:ordered_results)
      expect_any_instance_of(DefaultParamsFilterer).to_not receive(:paginate_results)
      filterer = DefaultParamsFilterer.filterer_chain({})
    end

    it 'provides a helper method to skip pagination' do
      expect_any_instance_of(DefaultParamsFilterer).to receive(:ordered_results).
        and_call_original
      expect_any_instance_of(DefaultParamsFilterer).to_not receive(:paginate_results)
      filterer = DefaultParamsFilterer.filter_without_pagination({})
    end
  end
end
