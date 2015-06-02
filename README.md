Filterer [![status]](https://circleci.com/gh/dobtco/filterer)  [![coverage]](https://coveralls.io/r/dobtco/filterer) [![codeclimate]](https://codeclimate.com/github/dobtco/filterer) [![gem]](http://badge.fury.io/rb/filterer)
====

Filterer lets your users easily filter results from your ActiveRecord models. What does that mean? Let's imagine a page in your application that lists the results of `Person.all`:

```
Name              Email           Admin?
----              ----            ----
Adam Becker       foo@bar.com     true
Barack Obama      bo@wh.gov       false
Joe Biden         joe@biden.com   true
```

What if you want to let your users filter the results by name? Or email? Or whether or not the Person is an admin? Where does that logic go?

One answer could be your controller. You could progressively build up a query, like so:

```ruby
@results = Person.all
@results = @results.where(name: params[:name]) if params[:name].present?
@results = @results.where(email: params[:email]) if params[:email].present?
@results = @results.where(admin: true) if params[:admin].present?
```

But you can see how that could get ugly fast. Especially when you add in sorting and pagination.

Another answer could be in your models. But passing a bunch of query parameters to a model isn't really a good practice either.

**Enter Filterer.**

## Using Filterer

First, add `gem 'filterer'` to your `Gemfile`.


Then generate the Filterer class:

```
rails generate filterer PersonFilterer
```

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

  # Optional default params
  def defaults
    {
      direction: 'desc'
    }
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

Now, when a user visits `/people`, they'll see Adam, Barack, and Joe, all three people. But when they visit `/people?name=Adam%20Becker`, they'll see only Adam. Or when they visit `/people?admin=t`, they'll see only Adam and Joe.

#### Pagination

Filterer includes its own pagination logic (described here). To use filterer with other gems, see the [alternative solutions section](#alternative-pagination-solutions). (This will likely be the supported behavior in the next major release.)

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
```

or

```ruby
class PersonFilterer < Filterer::Base
end

# In your controller...
PersonFilterer.new(params, starting_query: @organization.people)
```

#### Overriding per_page

```ruby
class PersonFilterer < Filterer::Base
  self.per_page = 30 # defaults to 20
end
```

#### Allowing the user to override per_page

```ruby
class PersonFilterer < Filterer::Base
  self.per_page = 20
  self.allow_per_page_override = true
end
```

Now you can append `?per_page=50` to the URL.

> Note: To prevent abuse, this value will still max-out at `1000` records per page.

#### Sorting the results

Filterer provides a slightly different DSL for sorting your results. Here's a quick overview of the different ways to use it:

```ruby
class PersonFilterer < Filterer::Base

  # '?sort=name' will order by LOWER(people.name). If there is no sort parameter,
  # we'll default to this anyway.
  sort_option 'name', 'LOWER(people.name)', default: true

  # '?sort=id' will order by id. This is used as a tiebreaker, so if two records
  # have the same name, the one with the lowest id will come first.
  sort_option 'id', tiebreaker: true

  # '?sort=occupation' will order by occupation, with NULLS LAST.
  sort_option 'occupation', nulls_last: true

  # '?sort=data1', '?sort=data2', etc. will call the following proc, passing the
  # query and match data
  sort_option Regexp.new('data([0-9]+)'), -> (query, match_data, filterer) {
    query.order('data -> ?', match_data[1])
  }

end
```

#### Chaining

An option is available to chain additional calls onto the filterer query.

```ruby
class PeopleController < ApplicationController
  def index
    @filterer = PersonFilterer.chain(params).my_custom_method
  end
end
```

In the view, we can then skip the call to `results` (i.e. `@filterer.each` vs `@filterer.results.each`).

(By default, chaining will _not_ apply ordering clauses. To obey ordering params, pass the `:include_ordering` option to `chain`.)

#### Alternative Pagination Solutions

Filterer supports basic pagination. This can be replaced by alternative pagination tools such as [Kaminari](https://github.com/amatsuda/kaminari) or [will_paginate](https://github.com/mislav/will_paginate).

Using the `chain` approach, we can control pagination ourselves:

```ruby
class PeopleController < ApplicationController
  def index
    @filterer = PersonFilterer.chain(params).page(params[:page]).per(10)
  end
end
```

The views should then use the helpers appropriate for the pagination gem used.

#### License
[MIT](http://dobt.mit-license.org)

[status]: https://circleci-badges.herokuapp.com/dobtco/filterer/4227dad9a04a91b070e9c25174f4035a2da6a828
[coverage]: https://img.shields.io/coveralls/dobtco/filterer.svg
[codeclimate]: https://img.shields.io/codeclimate/github/dobtco/filterer.svg
[gem]: https://img.shields.io/gem/v/filterer.svg
