class PeopleController < ApplicationController
  def index
    @people = PersonFilterer.filter(params)
  end

  def no_pagination
    @people = UnpaginatedPersonFilterer.filter(params)
    render :index
  end
end
