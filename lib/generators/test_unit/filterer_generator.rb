module TestUnit
  module Generators
    class FiltererGenerator < Rails::Generators::NamedBase
      desc "Generate a Filterer test in test/filterers/"

      argument :name, :type => :string, :required => true, :banner => 'FiltererName'

      source_root File.expand_path("../templates", __FILE__)

      def copy_files # :nodoc:
        template "filter_test.rb", "test/filterers/#{file_name}_test.rb"
      end
    end
  end
end
