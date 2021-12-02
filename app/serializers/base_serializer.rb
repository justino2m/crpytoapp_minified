class BaseSerializer < ActiveModel::Serializer
  include ApiRubyBase::SerializerMethods

  def self.timestamps
    attributes :updated_at, :created_at
  end

  def asset_path(path)
    ActionController::Base.helpers.asset_path(path)
  rescue Sprockets::Rails::Helper::AssetNotFound => e
    nil
  end
end
