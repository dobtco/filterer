Rails.application.routes.draw do

  resources :people do
    collection do
      get 'no_pagination'
    end
  end

end
