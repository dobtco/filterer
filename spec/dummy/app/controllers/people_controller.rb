class PeopleController < ApplicationController

  def index
    @filterer = PersonFilterer.new(params)
  end

end