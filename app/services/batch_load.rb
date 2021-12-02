class BatchLoad
  def self.call(query, size=1000, select_query=nil)
    ids = query.pluck(:id)
    ids.each_slice(size) do |chunk|
      # 'where' query doesnt return results in any order so we have to reorder them
      results = query.klass.where(id: chunk)
      results = results.select(select_query) if select_query

      # this is a hacky way of ensuring that we yield results in the correct order
      hash = {}
      chunk.each { |k| hash[k] = nil }
      results.each { |r| hash[r.id] = r }
      hash.each { |_, v| yield(v) }
    end
  end
end