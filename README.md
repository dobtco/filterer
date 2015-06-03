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

Next, you create a `Filterer` that looks like this:

```ruby
# app/filterers/person_filterer.rb

class PersonFilterer < Filterer::Base
  def param_name(x)
    results.where(name: x)
  end

  def param_email(x)
    results.where('LOWER(email) = ?', x)
  end

  def param_admin(x)
    results.where(admin: true)
  end

  # Optional default params
  def defaults
    {
      direction: 'desc'
    }
  end

  # Optional default filters
  def apply_default_filters
    results.where('deleted_at IS NULL')
  end
end
```

And in your controller:

```ruby
class PeopleController < ApplicationController
  def index
    @people = Person.filter(params)
  end
end
```

Now, when a user visits `/people`, they'll see Adam, Barack, and Joe, all three people. But when they visit `/people?name=Adam%20Becker`, they'll see only Adam. Or when they visit `/people?admin=t`, they'll see only Adam and Joe.

#### Specifying the Filterer class to use

Filterer includes a lightweight ActiveRecord adapter that allows us to call `filter` on any `ActiveRecord::Relation` like in the example above. By default, it will look for a class named `[ModelName]Filterer`. If you wish to override this, you have a couple of options:

You can pass a `:filterer_class` option to the call to `filter`:

```rb
Person.filter(params, filterer_class: 'AdvancedPersonFilterer')
```

Or you can bypass the ActiveRecord adapter altogether:

```rb
AdvancedPersonFilterer.filter(params, starting_query: Person.all)
```

### Pagination

Filterer relies on either [Kaminari](https://github.com/amatsuda/kaminari) or [will_paginate](https://github.com/mislav/will_paginate) for pagination. *You must install one of them if you want to paginate your records.*

If you have either of the above gems installed, Filterer will automatically paginate your records, fetching the correct page for the `?page=X` URL parameter. By default, filterer will display 20 records per page.

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

#### Disabling pagination

```rb
class NoPaginationFilterer < PersonFilterer
  self.per_page = nil
end
```

or

```rb
Person.filter(params, skip_pagination: true)
```

### Sorting the results

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
  sort_option Regexp.new('data([0-9]+)'), -> (query, matches, filterer) {
    query.order "(ratings -> '#{matches[1]}') #{filterer.sort_direction}"
  }
end
```

Since paginating records without an explicit `ORDER BY` clause is a no-no, Filterer orders by `[table_name].id asc` if no sort options are provided.

#### Disabling the ordering of results

For certain queries, you might want to bypass the ordering of results:

```rb
Person.filter(params, skip_ordering: true)
```

### Passing arbitrary data to the Filterer

```ruby
class OrganizationFilterer < Filterer::Base
  def starting_query
    if opts[:is_admin]
      Organization.all.with_deleted_records
    else
      Organization.all
    end
  end
end

OrganizationFilterer.filter(params, is_admin: current_user.admin?)
```

#### License

[MIT](http://dobt.mit-license.org)

[status]: https://circleci-badges.herokuapp.com/dobtco/filterer/4227dad9a04a91b070e9c25174f4035a2da6a828
[coverage]: https://img.shields.io/coveralls/dobtco/filterer.svg
[codeclimate]: https://img.shields.io/codeclimate/github/dobtco/filterer.svg
[gem]: https://img.shields.io/gem/v/filterer.svg
