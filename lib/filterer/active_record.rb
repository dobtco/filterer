module Filterer
  module ActiveRecord
    extend ActiveSupport::Concern

    class_methods do
      def filter(params = {}, opts = {})
        delegate_to_filterer(:filter, params, opts)
      end

      def chain(params = {}, opts = {})
        delegate_to_filterer(:chain, params, opts)
      end

      private

      def delegate_to_filterer(method, params, opts)
        filterer_class(opts[:filterer_class]).
          send(method, params, { starting_query: all }.merge(opts))
      end

      def filterer_class(override)
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
