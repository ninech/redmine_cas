require 'redmine'
require 'redmine_cas'
require 'redmine_cas/application_controller_patch'
require 'redmine_cas/account_controller_patch'

require_dependency 'redmine_cas_hook_listener'

Redmine::Plugin.register :redmine_cas do
  name 'Redmine CAS plugin'
  author 'Robert Auer (Triology GmbH)'
  description 'Plugin to CASify your Redmine installation.'
  version '1.2.3'
  url 'https://github.com/robertauer/redmine_cas'

  settings :default => {
    'enabled' => false,
    'cas_url' => 'https://',
    'attributes_mapping' => 'firstname=first_name&lastname=last_name&mail=email',
    'autocreate_users' => false
  }, :partial => 'redmine_cas/settings'

  Rails.configuration.to_prepare do
    ApplicationController.send(:include, RedmineCAS::ApplicationControllerPatch)
    AccountController.send(:include, RedmineCAS::AccountControllerPatch)
  end
  ActionDispatch::Callbacks.before do
    RedmineCAS.setup!
  end
end
