require './crawler.rb'
require './blog_post.rb'

url = "https://gapintelligence.com/blog"

crawler = Crawler.new
crawler.crawl(url)
