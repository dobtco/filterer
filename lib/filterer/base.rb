module Filterer
  class Base

    IGNORED_PARAMS = [:page]

    attr_accessor :results, :meta, :direction, :sort, :params, :opts

    class << self
      attr_accessor :sort_options, :per_page_num, :per_page_allow_override

      def sort_options
        @sort_options ||= []
      end

      def inherited(subclass)
        %w(sort_options per_page_num per_page_allow_override).each do |x|
          subclass.send("#{x}=", instance_variable_get("@#{x}"))
        end
      end

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

        sort_options << {
          key: key,
          query_string_or_proc: query_string_or_proc,
          opts: opts
        }
      end

      def per_page(num, opts = {})
        @per_page_num = num
        @per_page_allow_override = opts[:allow_override]
      end
    end

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
        per_page: get_per_page
      }
    end

    def get_per_page
      if self.class.per_page_allow_override && @params[:per_page].present?
        @params[:per_page]
      else
        self.class.per_page_num || 20
      end
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

        method_name = "param_#{k}"
        @results = respond_to?(method_name) ? send(method_name, v) : @results
      end
    end

    def order_results
      @direction = @params[:direction] == 'desc' ? 'DESC' : 'ASC'
      @sort = (params[:sort] && get_sort_option(params[:sort])) ? params[:sort] : default_sort_param
      return unless get_sort_option(@sort)

      if get_sort_option(@sort)[:query_string_or_proc].is_a?(String)
        @results = @results.order %Q{
          #{get_sort_option(@sort)[:query_string_or_proc]}
          #{@direction}
          #{get_sort_option(@sort)[:opts][:nulls_last] ? 'NULLS LAST' : ''}
          #{tiebreaker_sort_string ? ',' + tiebreaker_sort_string : ''}
        }.squish
      elsif get_sort_option(@sort)[:query_string_or_proc].is_a?(Proc)
        matches = get_sort_option(@sort)[:key].is_a?(Regexp) ? @sort.match(get_sort_option(@sort)[:key]) : nil
        @results = get_sort_option(@sort)[:query_string_or_proc].call(@results, matches, self)
      end
    end

    def get_sort_option(x)
      self.class.sort_options.find { |sort_option|
        if sort_option[:key].is_a?(Regexp)
          x.match(sort_option[:key])
        else # String
          x == sort_option[:key]
        end
      }
    end

    def default_sort_param
      self.class.sort_options.find { |sort_option|
        sort_option[:opts][:default]
      }.try(:[], :key)
    end

    def tiebreaker_sort_string
      self.class.sort_options.find { |sort_option|
        sort_option[:opts][:tiebreaker]
      }.try(:[], :query_string_or_proc)
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
