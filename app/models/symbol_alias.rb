class SymbolAlias < ApplicationRecord
  COMMON_TAG = 'common'.freeze
  TOKEN_ADDRESS_TAG = 'token_address'.freeze
  belongs_to :currency
  validates_presence_of :symbol, :tag, :currency_id
  validate :ensure_valid_token_address
  validate :ensure_uppercase

  def self.add_symbol_alias(tag, other_symbol, our_symbol_data, fail_if_not_found = true)
    other_symbol = other_symbol.to_s.upcase.strip
    return if SymbolAlias.where(tag: tag, symbol: other_symbol).exists?

    currencies = Currency.where(our_symbol_data).all
    return raise_error "multiple matches for alias #{other_symbol} -> #{our_symbol_data} (#{tag})" if currencies.count > 1
    if currencies.none?
      raise_error "cant find currency with data #{our_symbol_data}" if fail_if_not_found
      return
    end
    SymbolAlias.create!(tag: tag, symbol: other_symbol, currency: currencies.first)
  end

  # this is a separate method so we can mock it in specs
  def self.raise_error(error)
    raise error
  end

  private

  def ensure_valid_token_address
    if tag == TOKEN_ADDRESS_TAG && symbol.length < 5
      errors.add(:symbol, 'is not a valid token address')
    end
  end

  def ensure_uppercase
    self.symbol.upcase! if symbol.present?
  end
end
