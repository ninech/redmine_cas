require 'redmine_cas'

module RedmineCAS
  module ApplicationControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :verify_authenticity_token_without_cas, :verify_authenticity_token
        alias_method :verify_authenticity_token, :verify_authenticity_token_with_cas
        alias_method :require_login_without_cas, :require_login
        alias_method :require_login, :require_login_with_cas
        alias_method :original_check_if_login_required, :check_if_login_required
        alias_method :check_if_login_required, :cas_check_if_login_required
      end
    end

    module InstanceMethods
      def require_login_with_cas
        return require_login_without_cas unless RedmineCAS.enabled?
        if !User.current.logged?
          referrer = request.fullpath;
          respond_to do |format|
            # pass referer to cas action, to work around this problem:
            # https://github.com/ninech/redmine_cas/pull/13#issuecomment-53697288
            format.html { redirect_to :controller => 'account', :action => 'cas', :ref => referrer }
            format.atom { redirect_to :controller => 'account', :action => 'cas', :ref => referrer }
            format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
          end
          return false
        end
        true
      end

      def cas_check_if_login_required
        return true if original_check_if_login_required
        require_login if params.has_key?(:ticket)
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
