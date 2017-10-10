require './crawler.rb'
require './blog_post.rb'

julias_blog = BlogPost.new
julias_blog.name = 'Crawler 101 girl power'
julias_blog.author = 'Julia'

crawler = Crawler.new
crawler.crawl
