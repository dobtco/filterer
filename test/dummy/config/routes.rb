Rails.application.routes.draw do

  mount Filterer::Engine => "/filterer"
end
