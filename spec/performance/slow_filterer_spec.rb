require 'spec_helper'
require 'benchmark/ips'

describe 'Performance of SlowFilterer', performance: true do
  it 'performs fast' do
    Benchmark.ips do |x|
      params = {
        name: 'one',
        a: 'two',
        b: 'three',
        sort: 'field_21'
      }

      # Add a bunch of useless params, too
      (0..100).each do |x|
        params[x.to_s] = 'whatever'
      end

      x.report('filterer instantiation') do
        SlowFilterer.new(params)
      end
    end
  end
end
