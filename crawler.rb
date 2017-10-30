require 'mechanize'

class Crawler
  def crawl(page_url)
    agent = Mechanize.new
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    page = agent.get(page_url)
    puts page.uri
  end
end