RedmineApp::Application.routes.draw do
  get 'cas', :to => 'account#cas'
  post 'cas', :to => 'account#cas'
end
