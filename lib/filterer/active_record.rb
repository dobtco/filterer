module Filterer
  module ActiveRecord
    extend ActiveSupport::Concern

    included do
      def self.filter(params = {}, opts = {})
        filterer_class(opts[:filterer_class]).
          filter(params, opts.merge(starting_query: all))
      end

      def self.filterer_class(override)
        if override
          override.constantize
        else
          const_get("#{name}Filterer")
        end
      rescue
        fail "Looked for #{name}Filterer and couldn't find one!"
      end
    end
  end
end

ActiveRecord::Base.send(:include, Filterer::ActiveRecord)