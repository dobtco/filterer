module Filterer
  class Base

    attr_accessor :results, :meta, :direction, :sort, :params

    STANDARD_PARAMS = [:page]

    def initialize(params, opts = {})
      @params = params
      @opts = opts # @todo merge defaults

      setup_meta
      find_results
    end

    def paginator
      @paginator ||= Filterer::Paginator.new(self)
    end

    def setup_meta
      @meta = {}
      @meta[:page] = [@params[:page].to_i, 1].max
      @meta[:per_page] = 10
    end

    def find_results
      @results = starting_query

      # Add params
      add_params_to_query

      # Order results
      order_results

      @meta[:total] = @results.count
      @meta[:last_page] = [(@meta[:total].to_f / @meta[:per_page]).ceil, 1].max
      @meta[:page] = [@meta[:last_page], @meta[:page]].min

      return if @opts[:count_only]

      # Add custom meta data if we've defined the method
      @meta.merge!(self.custom_meta_data) if self.respond_to?(:custom_meta_data)

      @results = @results.limit(@meta[:per_page]).offset((@meta[:page] - 1)*@meta[:per_page])
    end

    def add_params_to_query
      @params.reject { |k, v| k.in?(STANDARD_PARAMS) }.each do |k, v|
        next unless respond_to?(:"param_#{k}")
        @results = send(:"param_#{k}", v) || @results
      end
    end

    def order_results
      # noop
    end

  end
end
