require 'redmine_cas'

module RedmineCAS
  module AccountControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :logout, :cas
      end
    end

    module InstanceMethods
      def logout_with_cas
        return logout_without_cas unless RedmineCAS.enabled?
        logout_user
        CASClient::Frameworks::Rails::Filter.logout(self, home_url)
      end
    end
  end
end
