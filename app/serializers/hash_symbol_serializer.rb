class HashSymbolSerializer < HashSerializer
  def self.load(hash)
    return {} unless hash
    JSON.parse(hash).symbolize_keys
  end
end
