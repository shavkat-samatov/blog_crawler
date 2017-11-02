require 'mechanize'
require 'byebug'
require 'active_support'
require 'active_support/core_ext'
require './blog_post.rb'
require './lib/mechanize_adapter.rb'

class Crawler
  def crawl(blog_url)
    agent = Mechanize.new
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    blog_page = agent.get(blog_url)

    puts blog_page.title
  end
end
