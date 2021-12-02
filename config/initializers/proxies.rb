module Proxies
  extend self

  PROXIES = %w[ jumbojet:8uYlUVRNX3vbowaY1Ow@196.196.222.175:12345
  ].freeze

  def fetch_proxy
    URI("http://#{PROXIES.sample}")
  end
end
