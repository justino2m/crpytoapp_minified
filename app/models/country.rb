class Country < ApplicationRecord
  belongs_to :currency
  before_validation :set_defaults
  validates_presence_of :name, :code
  validates_inclusion_of :tax_cost_basis_method, in: Investment::COST_BASIS_METHODS
  validates_inclusion_of :tax_year_start_day, in: 1..31
  validates_inclusion_of :tax_year_start_month, in: 1..12

  serialize :metadata, HashSerializer
  store_accessor :metadata, :tax_cost_basis_method, :tax_minimum_filing_volume, :tax_year_start_day, :tax_year_start_month, :tax_info_url, :verified

  def self.usa
    cache_on_prod('USA')
  end

  def self.uk
    cache_on_prod('GBR')
  end

  def timezone
    TZInfo::Country.get(iso_data.alpha2).zone_identifiers.first
  end

  def iso_data
    IsoCountryCodes.find(code)
  end

  def has_long_term?
    %w[USA DEU DNK AUS].include?(code)
  end

  def long_term?(bought, sold)
    return false unless bought && sold
    bought, sold = [bought.to_datetime, sold.to_datetime].sort
    case code
    when 'USA', 'AUS'
      sold > (bought.end_of_day + 1.year)
    when 'DEU' # germany
      sold > (bought + 1.year)
    when 'DNK' # denmark
      sold.year != bought.year # only same year losses can be deducted against each other
    else
      false
    end
  end

  private

  def set_defaults
    self.tax_cost_basis_method ||= Investment::COST_BASIS_METHODS[0]
    self.tax_minimum_filing_volume ||= 0
    self.tax_year_start_day ||= 1
    self.tax_year_start_month ||= 1
  end

  def self.cache_on_prod(code)
    if Rails.env.test?
      find_by(code: code)
    else
      @cached ||= {}
      @cached[code] ||= find_by(code: code)
    end
  end
end
