class Crawler
  def crawl
  	julias_blog = BlogPost.new
    julias_blog.name = 'Crawler 101 girl power'
    julias_blog.author = 'Julia'

    sarinas_blog = BlogPost.new
    sarinas_blog.name = 'Paper yay'
    sarinas_blog.author = 'Sarina'

    blogs = [julias_blog, sarinas_blog]

    blogs.each do |current_blog|
      puts "This blog is called #{current_blog.name}. And it's written by #{current_blog.author}!!!!!!"
    end

    puts "uh oh"
  end
end