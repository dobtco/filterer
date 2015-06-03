# Load the Rails application.
require File.expand_path('../application', __FILE__)

if ENV['WILL_PAGINATE']
  require 'will_paginate'
else
  require 'kaminari'
end

# Initialize the Rails application.
Dummy::Application.initialize!
