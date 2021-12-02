class WalletService < ApplicationRecord
  has_many :wallets, dependent: :destroy
  scope :active, -> { where(active: true) }
  validates_presence_of :name, :tag
  has_attached_file :icon, styles: { medium: "300x300>", thumb: "100x100>" }
  validates_attachment_content_type :icon, content_type: /\Aimage\/.*\z/
  alias_attribute :type, :integration_type

  TYPES = [
    EXCHANGE = 'exchange',
    BLOCKCHAIN = 'blockchain',
    WALLET = 'wallet',
    OTHER = 'other'
  ]

  def api_importer_klass
    api_importer&.constantize
  end

  def api_required_fields
    api_importer_klass&.required_options || []
  end

  def api_oauth_url
    api_importer_klass&.oauth_url
  end
end
