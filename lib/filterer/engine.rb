module Filterer
  class Engine < ::Rails::Engine
    isolate_namespace Filterer

    ActiveSupport.on_load(:active_record) do
      require 'filterer/active_record'
    end
  end
end
