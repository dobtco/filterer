module Filterer
  class Base
    IGNORED_PARAMS = %w(page)

    attr_accessor :results, :meta, :direction, :sort, :params, :opts

    class_attribute :sort_options
    self.sort_options = []

    class_attribute :per_page
    self.per_page = 20

    class_attribute :per_page_allow_override
    self.per_page_allow_override = false

    class_attribute :per_page_max
    self.per_page_max = 1000

    class << self
      def sort_option(key, query_string_or_proc = nil, opts = {})
        if query_string_or_proc.is_a?(Hash)
          opts, query_string_or_proc = query_string_or_proc.clone, nil
        end

        if !query_string_or_proc
          if key.is_a?(String)
            query_string_or_proc = key
          else
            raise 'Please provide a query string or a proc.'
          end
        end

        if key.is_a?(Regexp) && opts[:default]
          raise "Default sort option can't have a Regexp key."
        end

        if query_string_or_proc.is_a?(Proc) && opts[:tiebreaker]
          raise "Tiebreaker can't be a proc."
        end

        self.sort_options += [{
          key: key,
          query_string_or_proc: query_string_or_proc,
          opts: opts
        }]
      end

      def count(params = {}, opts = {})
        self.new(params, { meta_only: true }.merge(opts)).meta[:total]
      end

      def chain(params = {}, opts = {})
        self.new(params, { chainable: true }.merge(opts)).results
      end
    end

    def defaults
      {}
    end

    def initialize(params = {}, opts = {})
      @params, @opts = defaults.merge(params).with_indifferent_access, opts
      setup_meta
      find_results
    end

    def paginator
      @paginator ||= Filterer::Paginator.new(self)
    end

    def setup_meta
      @meta = {
        page: [@params[:page].to_i, 1].max,
        per_page: get_per_page
      }
    end

    def get_per_page
      if self.class.per_page_allow_override && @params[:per_page].present?
        [@params[:per_page], self.per_page_max].min
      else
        self.class.per_page
      end
    end

    def find_results
      @results = opts.delete(:starting_query) || starting_query
      add_params_to_query
      return if @opts[:chainable]
      order_results
      add_meta
      return if @opts[:meta_only]

      # Add custom meta data if we've defined the method
      @meta.merge!(self.custom_meta_data) if self.respond_to?(:custom_meta_data)

      # Return the paginated results
      @results = @results.limit(@meta[:per_page]).offset((@meta[:page] - 1)*@meta[:per_page])
    end

    def add_meta
      @meta[:total] = @results.unscope(:select).count
      @meta[:last_page] = [(@meta[:total].to_f / @meta[:per_page]).ceil, 1].max
      @meta[:page] = [@meta[:last_page], @meta[:page]].min
    end

    def add_params_to_query
      @params.reject { |k, v| k.to_s.in?(IGNORED_PARAMS) }
             .select { |k, v| v.present? }
             .each do |k, v|

        method_name = "param_#{k}"
        @results = respond_to?(method_name) ? send(method_name, v) : @results
      end
    end

    def order_results
      @direction = @params[:direction] == 'desc' ? 'DESC' : 'ASC'
      @sort = (params[:sort] && get_sort_option(params[:sort])) ? params[:sort] : default_sort_param

      if !get_sort_option(@sort)
        @results = @results.order default_sort_sql
      elsif get_sort_option(@sort)[:query_string_or_proc].is_a?(String)
        @results = @results.order basic_sort_sql
      elsif get_sort_option(@sort)[:query_string_or_proc].is_a?(Proc)
        apply_sort_proc
      end
    end

    def default_sort_sql
      "#{@results.model.table_name}.id ASC"
    end

    def basic_sort_sql
      %{
        #{get_sort_option(@sort)[:query_string_or_proc]}
        #{@direction}
        #{get_sort_option(@sort)[:opts][:nulls_last] ? 'NULLS LAST' : ''}
        #{tiebreaker_sort_string ? ',' + tiebreaker_sort_string : ''}
      }.squish
    end

    def apply_sort_proc
      sort_key = get_sort_option(@sort)[:key]
      matches = sort_key.is_a?(Regexp) && @sort.match(sort_key)
      @results = get_sort_option(@sort)[:query_string_or_proc].call(@results, matches, self)
    end

    def get_sort_option(x)
      self.class.sort_options.detect do |sort_option|
        if sort_option[:key].is_a?(Regexp)
          x.match(sort_option[:key])
        else # String
          x == sort_option[:key]
        end
      end
    end

    def default_sort_param
      self.class.sort_options.detect do |sort_option|
        sort_option[:opts][:default]
      end.try(:[], :key)
    end

    def tiebreaker_sort_string
      self.class.sort_options.detect do |sort_option|
        sort_option[:opts][:tiebreaker]
      end.try(:[], :query_string_or_proc)
    end

    def starting_query
      raise 'You must override this method!'
    end
  end
end
