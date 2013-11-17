class FiltererGenerator < Rails::Generators::NamedBase
  desc "Generate a Filterer in app/filterers/"

  argument :name, :type => :string, :required => true, :banner => 'FiltererName'

  source_root File.expand_path("../templates", __FILE__)

  def copy_files # :nodoc:
    template "filter.rb", "app/filterers/#{file_name}.rb"
  end

  hook_for :test_framework
end
