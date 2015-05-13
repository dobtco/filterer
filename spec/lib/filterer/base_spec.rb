require 'spec_helper'

class FakeQuery
  COUNT = 5

  def method_missing(method, *args)
    self
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
  self.per_page = 30
end

class PaginationFiltererWithOverride < PaginationFilterer
  self.per_page = 20
  self.per_page_allow_override = true
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

  it 'basic smoke test' do
    expect_any_instance_of(SmokeTestFilterer).to receive(:starting_query).and_return(f = FakeQuery.new)
    expect_any_instance_of(SmokeTestFilterer).to receive(:respond_to?).with(:custom_meta_data).and_return(false)
    expect(f).to receive(:limit).with(20).and_return(f)
    expect(f).to receive(:offset).with(0).and_return(f)

    @filterer = SmokeTestFilterer.new
    expect(@filterer.meta[:page]).to eq(1)
    expect(@filterer.meta[:last_page]).to eq(1)
    expect(@filterer.meta[:total]).to eq(FakeQuery::COUNT)
  end

  it 'passes parameters to the correct methods' do
    expect_any_instance_of(SmokeTestFilterer).to receive(:param_foo).with('bar').and_return(FakeQuery.new)
    @filterer = SmokeTestFilterer.new({ foo: 'bar' })
  end

  it 'does not pass the :page parameter' do
    expect_any_instance_of(SmokeTestFilterer).not_to receive(:param_page)
    @filterer = SmokeTestFilterer.new({ page: 'bar' })
  end

  it 'does not pass blank parameters' do
    expect_any_instance_of(SmokeTestFilterer).not_to receive(:param_foo)
    @filterer = SmokeTestFilterer.new({ foo: '' })
  end

  it 'has a paginator' do
    @filterer = SmokeTestFilterer.new({ foo: '' })
    expect(@filterer.paginator).to be_a(Filterer::Paginator)
  end

  it 'calculates more complex page numbers and totals' do
    higher_count = 35

    expect_any_instance_of(SmokeTestFilterer).to receive(:starting_query).and_return(f = FakeQuery.new)
    expect(f).to receive(:limit).with(20).and_return(f)
    expect(f).to receive(:offset).with(20).and_return(f)
    stub_const("FakeQuery::COUNT", higher_count)

    @filterer = SmokeTestFilterer.new({ page: 2 }, { })
    expect(@filterer.meta[:page]).to eq(2)
    expect(@filterer.meta[:last_page]).to eq(2)
    expect(@filterer.meta[:total]).to eq(higher_count)
  end

  it 'can count without all the other stuff' do
    expect_any_instance_of(FakeQuery).not_to receive(:limit)
    expect_any_instance_of(SmokeTestFilterer).to receive(:param_foo).with('bar').and_return(FakeQuery.new)
    expect(SmokeTestFilterer.count({ foo: 'bar' })).to eq(FakeQuery::COUNT)
  end

  it 'can add custom meta data' do
    allow_any_instance_of(SmokeTestFilterer).to receive(:custom_meta_data).and_return({ bar: 'baz' })
    @filterer = SmokeTestFilterer.new
    expect(@filterer.meta[:bar]).to eq('baz')
  end

  describe 'sorting' do
    it 'orders by ID by default' do
      filterer = SmokeTestFilterer.new
      expect(filterer.sort).to be_nil

      expect_any_instance_of(FakeQuery).to(
        receive_message_chain(:model, :table_name).
          and_return('asdf')
      )

      expect_any_instance_of(FakeQuery).to receive(:order).
        with('asdf.id ASC')

      filterer.order_results
    end

    it 'can apply a default sort' do
      filterer = SortingFiltererA.new
      expect(filterer.sort).to eq('id')
    end

    it 'can apply a default sort when inheriting a class' do
      filterer = InheritedSortingFiltererA.new
      expect(filterer.sort).to eq('id')
    end

    it 'can include a tiebreaker' do
      expect_any_instance_of(FakeQuery).to receive(:order).with(/thetiebreaker/).and_return(FakeQuery.new)
      filterer = SortingFiltererB.new
      expect(filterer.sort).to eq('id')
    end

    it 'can match by regexp' do
      filterer = SortingFiltererC.new(sort: 'foo111')
      expect(filterer.sort).to eq('foo111')
    end

    it 'does not choke on a nil param' do
      filterer = SortingFiltererC.new
      expect(filterer.sort).to eq('id')
    end

    it 'can apply a proc' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('111 ASC').and_return(FakeQuery.new)
      filterer = SortingFiltererC.new(sort: 'foo111')
      expect(filterer.sort).to eq('foo111')
    end

    it 'can put nulls last' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('baz ASC NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo')
    end

    it 'can change to desc' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('baz DESC NULLS LAST').and_return(FakeQuery.new)
      filterer = SortingFiltererD.new(sort: 'foo', direction: 'desc')
    end

    it 'can distinguish between two regexps' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('zoo').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'zoo111')
      expect(filterer.sort).to eq('zoo111')
    end

    it 'can distinguish between two regexps part 2' do
      expect_any_instance_of(FakeQuery).to receive(:order).with('111 ASC').and_return(FakeQuery.new)
      filterer = SortingFiltererE.new(sort: 'foo111')
      expect(filterer.sort).to eq('foo111')
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
        expect(@filterer.meta[:per_page]).to eq(20)
      end

      it 'can be set to another value' do
        @filterer = PaginationFiltererB.new
        expect(@filterer.meta[:per_page]).to eq(30)
      end

      it 'inherits when subclassing' do
        @filterer = PaginationFiltererInherit.new
        expect(@filterer.meta[:per_page]).to eq(30)
      end

      it 'can be overriden' do
        @filterer = PaginationFiltererWithOverride.new
        expect(@filterer.meta[:per_page]).to eq(20)
        @filterer = PaginationFiltererWithOverride.new(per_page: 15)
        expect(@filterer.meta[:per_page]).to eq(15)
      end

      it 'can not be overriden past max' do
        @filterer = PaginationFiltererWithOverride.new(per_page: 100000)
        expect(@filterer.meta[:per_page]).to eq(1000)
      end
    end
  end

  describe 'unscoping' do
    it 'unscopes select' do
      @filterer = UnscopedFilterer.new
      expect(@filterer.meta[:total]).to eq(0)
    end
  end

  describe 'chain' do
    it 'chains properly' do
      expect_any_instance_of(FakeQuery).to_not receive(:order).with(/id/)
      expect_any_instance_of(FakeQuery).to receive(:order).with(/foobar/).and_return(FakeQuery.new)
      SortingFiltererA.chain({}).order('foobar')
    end

    it 'uses the :include_ordering option' do
      expect_any_instance_of(FakeQuery).to receive(:order).with(/id/).and_return(FakeQuery.new)
      SortingFiltererA.chain({}, include_ordering: true)
    end
  end

end
