require 'redmine_cas'

module RedmineCAS
  module ApplicationControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :verify_authenticity_token, :cas
        alias_method_chain :require_login, :cas
      end
    end

    module InstanceMethods
      def require_login_with_cas
        return require_login_without_cas unless RedmineCAS.enabled?
        if !User.current.logged?
          respond_to do |format|
            format.html { redirect_to :controller => 'account', :action => 'cas' }
            format.atom { redirect_to :controller => 'account', :action => 'cas' }
            format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
          end
          return false
        end
        true
      end

      def verify_authenticity_token_with_cas
        if cas_logout_request?
          logger.info 'CAS logout request detected: Skipping validation of authenticity token'
        else
          verify_authenticity_token_without_cas
        end
      end

      def cas_logout_request?
        request.post? && params.has_key?('logoutRequest')
      end

    end
  end
end
