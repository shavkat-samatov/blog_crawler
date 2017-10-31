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

    blog_page = agent.get(page_url)

    url = blog_page.resolve_url(blog_page.extract('.b-post a', attr: :href))

    post_page = agent.get(url)

    puts post_page.extract("h1")
  end
end
