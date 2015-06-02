class PeopleController < ApplicationController
  def index
    @people = PersonFilterer.filter(params)
  end
end
