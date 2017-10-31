require 'mechanize'
require 'byebug'
require 'active_support'
require 'active_support/core_ext'
require './blog_post.rb'
require './lib/mechanize_adapter.rb'

class Crawler
  def crawl(page_url)
    agent = Mechanize.new
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    page = agent.get(page_url)

    puts page.extract('h1')
  end
end