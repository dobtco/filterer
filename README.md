Filterer ![status](https://circleci.com/gh/dobtco/filterer.png?circle-token=4227dad9a04a91b070e9c25174f4035a2da6a828) [![Coverage Status](https://coveralls.io/repos/dobtco/filterer/badge.png)](https://coveralls.io/r/dobtco/filterer) [![code climate](https://d3s6mut3hikguw.cloudfront.net/github/dobtco/filterer.png)](https://codeclimate.com/github/dobtco/filterer)
====

Filterer lets your users easily filter results from your ActiveRecord models. What does that mean? Let's imagine a page in your application that lists the results of `Person.all`:

```
Name              Email           Admin?
----              ----            ----
Adam Becker       foo@bar.com     true
Barack Obama      bo@wh.gov       false
Joe Biden         joe@biden.com   false
```

What if you want to let your users filter the results by name? Or email? Or whether or not the Person is an admin? Where does that logic go?

One answer could be your controller. You could progressively build up a query, like so:

```ruby
@results = Person.all
@results = @results.where(name: params[:name]) if params[:name].present?
@results = @results.where(email: params[:email]) if params[:email].present?
@results = @results.where(admin: true) if params[:admin].present?
```

But you can see how that could get ugly fast. Especially when you add in sorting, and pagination.

Another answer could be in your models. But passing a bunch of query parameters to a model isn't really a good practice either.

**Enter Filterer.**

## Using Filterer

First, add `gem 'filterer'` to your `Gemfile`.

And then instead of throwing all of this logic into a controller or model, you create a `Filterer` that looks like this:

```ruby
# app/filterers/person_filterer.rb

class PersonFilterer < Filterer::Base
  def starting_query
    Person.where('deleted_at IS NULL')
  end

  def param_name(x)
    @results.where(name: x)
  end

  def param_email(x)
    @results.where('LOWER(email) = ?', x)
  end

  def param_admin(x)
    @results.where(admin: true)
  end
end
```

And in your controller:

```ruby
class PeopleController < ApplicationController
  def index
    @filterer = PersonFilterer.new(params)
  end
end
```

And in your views:

```erb
<% @filterer.results.each do |person| %>
  ...
<% end %>
```

#### Pagination

In your controller:
```ruby
helper Filterer::PaginationHelper
```

In your view:
```erb
<%= render_filterer_pagination(@filterer) %>
```

#### Passing options to the Filterer

```ruby
class PersonFilterer < Filterer::Base
  def starting_query
    @opts[:organization].people.where('deleted_at IS NULL')
  end
end

...

PersonFilterer.new(params, organization: Organization.find(4))
```

#### Sorting the results

Filterer isn't too opinionated in this case, but here's what we use:

```ruby
class PersonFilterer < Filterer::Base
  ...

  def valid_sort_options
    {
      'submitted' => 'submitted_at',
      'popularity' => 'votes_count'
    }
  end

  def order_results
    @direction = @params[:direction] == 'desc' ? 'DESC' : 'ASC'
    @sort = @params[:sort].in?(valid_sort_options.keys) ? @params[:sort] : 'submitted'
    @results = @results.order("#{valid_sort_options[@sort]} #{@direction}, people.id")
  end
end
```

Note that if you define an `order_results` method, it will get called automatically.

#### License
MIT