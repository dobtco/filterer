module Filterer
  class Base
    attr_accessor :results,
                  :meta,
                  :direction,
                  :sort,
                  :params,
                  :opts

    class_attribute :sort_options
    self.sort_options = []

    class_attribute :per_page
    self.per_page = 20

    class_attribute :allow_per_page_override
    self.allow_per_page_override = false

    class_attribute :per_page_max
    self.per_page_max = 1000

    class << self
      # Macro for adding sort options
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

      # Public API
      # @return [ActiveRecord::Association]
      def filter(*args)
        new(*args).results
      end
    end

    def initialize(params = {}, opts = {})
      self.params = defaults.merge(params).with_indifferent_access
      self.opts = opts
      self.results = opts[:starting_query] || starting_query
      add_params_to_query
      order_results unless opts[:skip_ordering]
      paginate_results unless opts[:skip_pagination]

      # Add custom meta data if we've defined the method
      # @meta.merge!(self.custom_meta_data) if self.respond_to?(:custom_meta_data)
    end

    def defaults
      {}
    end

    def starting_query
      raise 'You must override this method!'
    end

    private

    def paginate_results
      if per_page && paginator
        send("paginate_results_with_#{paginator}")
      end
    end

    def paginator
      if defined?(Kaminari)
        :kaminari
      elsif defined?(WillPaginate)
        :will_paginate
      end
    end

    def paginate_results_with_kaminari
      self.results = results.page(current_page).per(per_page)
    end

    def paginate_results_with_will_paginate
      self.results = results.paginate(page: current_page, per_page: per_page)
    end

    def add_params_to_query
      present_params.each do |k, v|
        method_name = "param_#{k}"

        if respond_to?(method_name)
          self.results = send(method_name, v)
        end
      end
    end

    def present_params
      params.select do |_k, v|
        v.present?
      end
    end

    def order_results
      self.direction = params[:direction].try(:downcase) == 'desc' ? 'desc' : 'asc'
      self.sort = if (params[:sort] && get_sort_option(params[:sort]))
                    params[:sort]
                  else
                    default_sort_param
                  end

      if !get_sort_option(sort)
        self.results = results.order default_sort_sql
      elsif get_sort_option(sort)[:query_string_or_proc].is_a?(String)
        self.results = results.order basic_sort_sql
      elsif get_sort_option(sort)[:query_string_or_proc].is_a?(Proc)
        apply_sort_proc
      end
    end

    def default_sort_sql
      "#{results.model.table_name}.id asc"
    end

    def basic_sort_sql
      %{
        #{get_sort_option(sort)[:query_string_or_proc]}
        #{direction}
        #{get_sort_option(sort)[:opts][:nulls_last] ? 'NULLS LAST' : ''}
        #{tiebreaker_sort_string ? ',' + tiebreaker_sort_string : ''}
      }.squish
    end

    def per_page
      if self.class.allow_per_page_override && params[:per_page].present?
        [params[:per_page], self.per_page_max].min
      else
        self.class.per_page
      end
    end

    def current_page
      [params[:page].to_i, 1].max
    end

    def apply_sort_proc
      sort_key = get_sort_option(sort)[:key]
      matches = sort_key.is_a?(Regexp) && sort.match(sort_key)
      self.results = get_sort_option(sort)[:query_string_or_proc].call(results, matches, self)
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
  end
end
