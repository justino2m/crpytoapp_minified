class AssetsUpdater
  def self.update(user)
    currency_ids = user.accounts.pluck(:currency_id)
    currency_ids.each do |id|
      yield if block_given?
      asset = user.assets.where(currency_id: id).first_or_initialize
      asset.update_totals!
    end

    # delete assets that there are no accounts for
    user.assets.where.not(currency_id: currency_ids).delete_all
  end
end
