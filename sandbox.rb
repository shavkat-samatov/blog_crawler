require './crawler.rb'

page = Nokogiri::HTML(open('selectors.html'))

puts page.extract('')