class PersonFilterer < Filterer::Base

  def starting_query
    Person
  end

  def param_name(x)
    @results.where(name: x)
  end

end