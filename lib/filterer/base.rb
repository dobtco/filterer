module Filterer
  class Base

    attr_accessor :results, :meta, :direction, :sort, :params

    IGNORED_PARAMS = [:page]

    def initialize(params = {}, opts = {})
      @params, @opts = params, opts
      setup_meta
      find_results
    end

    def paginator
      @paginator ||= Filterer::Paginator.new(self)
    end

    def setup_meta
      @meta = {
        page: [@params[:page].to_i, 1].max,
        per_page: 10
      }
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
      @params.reject { |k, v| k.in?(IGNORED_PARAMS) }
             .select { |k, v| v.present? }
             .each do |k, v|

        method_name = :"param_#{k}"
        @results = respond_to?(method_name) ? send(method_name, v) : @results
      end
    end

    def order_results
      # noop
    end

    def starting_query
      raise 'You must override this method!'
    end

    def self.count(params = {}, opts = {})
      filterer = self.new(params, { count_only: true }.merge(opts))
      return filterer.meta[:total]
    end

  end
end
