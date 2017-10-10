class BlogPost
	attr_reader :company
  attr_accessor :name, :number_of_shares, :author, :date

  def initialize
    @company = 'gap intelligence'
  end
end