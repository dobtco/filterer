Filterer ![status](https://circleci.com/gh/dobtco/filterer.png?circle-token=4227dad9a04a91b070e9c25174f4035a2da6a828) [![Coverage Status](https://coveralls.io/repos/dobtco/filterer/badge.png)](https://coveralls.io/r/dobtco/filterer) ![code climate](https://d3s6mut3hikguw.cloudfront.net/github/dobtco/filterer.png)
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

#### About

#### Usage

#### License
MIT