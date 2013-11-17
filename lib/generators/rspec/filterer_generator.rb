module Rspec
  module Generators
    class FiltererGenerator < Rails::Generators::NamedBase
      desc "Generate a Filterer spec in spec/filterers/"

      argument :name, :type => :string, :required => true, :banner => 'FiltererName'

      source_root File.expand_path("../templates", __FILE__)

      def copy_files # :nodoc:
        template "filter_spec.rb", "spec/filterers/#{file_name}_spec.rb"
      end
    end
  end
end
