# encoding: UTF-8

Rails.application.routes.draw do

  namespace :distribute_tree do
    resources :distribute do
      get  :servers, :paperclip_file
      post :receive
    end
  end

end
