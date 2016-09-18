module Filterer
  class Base
    attr_accessor :results,
                  :meta,
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
      def sort_option(key, string_or_proc = nil, opts = {})
        if string_or_proc.is_a?(Hash)
          opts, string_or_proc = string_or_proc.clone, nil
        end

        if !string_or_proc
          if key.is_a?(String)
            string_or_proc = key
          else
            raise 'Please provide a query string or a proc.'
          end
        end

        if key.is_a?(Regexp) && opts[:default]
          raise "Default sort option can't have a Regexp key."
        end

        if string_or_proc.is_a?(Proc) && opts[:tiebreaker]
          raise "Tiebreaker can't be a proc."
        end

        self.sort_options += [{
          key: key,
          string_or_proc: string_or_proc,
          opts: opts
        }]
      end

      # Public API
      # @return [ActiveRecord::Association]
      def filter(params = {}, opts = {})
        new(params, opts).results
      end

      # @return [ActiveRecord::Association]
      def filter_without_pagination(params = {}, opts = {})
        new(params, opts.merge(
          skip_pagination: true
        )).results
      end

      # @return [ActiveRecord::Association]
      def chain(params = {}, opts = {})
        new(params, opts.merge(
          skip_ordering: true,
          skip_pagination: true
        )).results
      end
    end

    def initialize(params = {}, opts = {})
      self.opts = opts
      self.params = defaults.merge(params).with_indifferent_access
      self.results = opts[:starting_query] || starting_query
      self.results = apply_default_filters || results
      add_params_to_query
      self.results = ordered_results unless opts[:skip_ordering]
      paginate_results unless opts[:skip_pagination]
      extend_active_record_relation
    end

    def defaults
      {}
    end

    def starting_query
      raise 'You must override this method!'
    end

    def direction
      params[:direction].try(:downcase) == 'desc' ? 'desc' : 'asc'
    end

    # @return [String] the key for the applied sort option.
    def sort
      @sort ||= begin
        if params[:sort] && find_sort_option_from_param(params[:sort])
          params[:sort]
        else
          default_sort_option[:key]
        end
      end
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

    def apply_default_filters
      results
    end

    def add_params_to_query
      present_params.each do |k, v|
        method_name = "param_#{k}"

        if respond_to?(method_name)
          self.results = send(method_name, v) || results
        end
      end
    end

    def present_params
      params.select do |_k, v|
        v.present?
      end
    end

    def ordered_results
      if sort_option && sort_option[:string_or_proc].is_a?(String)
        order_by_sort_option(sort_option)
      elsif sort_option && sort_option[:string_or_proc].is_a?(Proc)
        order_by_sort_proc
      else
        order_by_sort_option(default_sort_option)
      end
    end

    def per_page
      if self.class.allow_per_page_override && params[:per_page].present?
        [params[:per_page].to_i, per_page_max].min
      else
        self.class.per_page
      end
    end

    def current_page
      [params[:page].to_i, 1].max
    end

    def sort_option
      @sort_option ||= find_sort_option_from_param(sort)
    end

    # @param x [String]
    # @return [Hash] sort_option
    def find_sort_option_from_param(x)
      self.class.sort_options.detect do |sort_option|
        if sort_option[:key].is_a?(Regexp)
          x.match(sort_option[:key])
        else # String
          x == sort_option[:key]
        end
      end
    end

    def order_by_sort_proc
      if (sort_string = sort_proc_to_string(sort_option))
        order_by_sort_option(sort_option.merge(
          string_or_proc: sort_string
        ))
      else
        order_by_sort_option(filterer_default_sort_option)
      end
    end

    def order_by_sort_option(opt)
      results.order %{
        #{opt[:string_or_proc]}
        #{direction}
        #{opt[:opts][:nulls_last] ? 'NULLS LAST' : ''}
        #{tiebreaker_sort_string ? ', ' + tiebreaker_sort_string : ''}
      }.squish
    end

    def sort_proc_to_string(opt)
      sort_key = opt[:key]
      matches = sort_key.is_a?(Regexp) && params[:sort].match(sort_key)
      instance_exec matches, &opt[:string_or_proc]
    end

    def default_sort_option
      self.class.sort_options.detect do |sort_option|
        sort_option[:opts][:default]
      end || filterer_default_sort_option
    end

    def filterer_default_sort_option
      {
        key: 'default',
        string_or_proc: "#{results.model.table_name}.id",
        opts: {}
      }
    end

    def tiebreaker_sort_string
      self.class.sort_options.detect do |sort_option|
        sort_option[:opts][:tiebreaker]
      end.try(:[], :string_or_proc)
    end

    def extend_active_record_relation
      results.instance_variable_set(:@filterer, self)

      results.extending! do
        def filterer
          @filterer
        end
      end
    end
  end
end
