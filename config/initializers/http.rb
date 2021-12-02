require 'http/headers'

# HTTP modifies the header names, replacing underscores with dashes and
# capitalizing each word, this causes issues with api's that expect
# certain headers.
HTTP::Headers.class_eval do
  alias old_normalize_header normalize_header
  def normalize_header(name)
    name
  end
end

module HTTP::Chainable
  def with_scraper
    self
  end

  def with_proxy(proxy=Proxies.fetch_proxy)
    return self unless proxy
    puts "using proxy #{proxy.to_s}" unless Rails.env.test?
    via(*uri_to_proxy(proxy))
  end
  
  def uri_to_proxy(uri)
    [uri.host, uri.port, uri.user, uri.password]
  end
end
