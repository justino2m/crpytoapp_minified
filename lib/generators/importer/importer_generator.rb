class ImporterGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  argument :methods, type: :array, banner: "api_key api_secret"

  def copy_pattern_file
    template "api.erb", "app/api/#{file_name}_api.rb"
    template "importer.erb", "app/importers/#{file_name}_importer.rb"
    template "spec.erb", "spec/importers/#{file_name}_importer_spec.rb"
  end

  private

  def class_name
    file_name.camelcase
  end
end
