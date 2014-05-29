require 'redmine_cas'

module RedmineCAS
  module ApplicationControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :verify_authenticity_token, :cas
        alias_method_chain :require_login, :cas
        alias_method_chain :session_expiration, :cas
      end
    end

    module InstanceMethods
      def require_login_with_cas
        return require_login_without_cas unless RedmineCAS.enabled?
        if !User.current.logged?
          respond_to do |format|
            format.html { login_with_cas }
            format.atom { login_with_cas }
            format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
            format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
          end
          return false
        end
        true
      end

      def login_with_cas
        if CASClient::Frameworks::Rails::Filter.filter(self)
          user = User.find_by_login(session[:cas_user])

          # Auto-create user if possible
          if user.nil? && RedmineCAS.autocreate_users?
            user = User.new
            user.login = session[:cas_user]
            user.assign_attributes(RedmineCAS.user_extra_attributes_from_session(session))
            return cas_user_not_created(user) if !user.save
            user.reload
          end

          return cas_user_not_found if user.nil?
          return cas_account_pending unless user.active?
          user.update_attribute(:last_login_on, Time.now)
          user.update_attributes(RedmineCAS.user_extra_attributes_from_session(session))
          if RedmineCAS.single_sign_out_enabled?
            # logged_user= would start a new session and break single sign-out
            User.current = user
            start_user_session(user)
          else
            self.logged_user = user
          end
          redirect_to url_for(params.merge(:ticket => nil))
        else
          # CASClient called redirect_to
        end
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

      def cas_account_pending
        render_403 :message => l(:notice_account_pending)
      end

      def cas_user_not_found
        render_403 :message => l(:redmine_cas_user_not_found, :user => session[:cas_user])
      end

      def cas_user_not_created(user)
        logger.error "Could not auto-create user: #{user.errors.full_messages.to_sentence}"
        render_403 :message => l(:redmine_cas_user_not_created, :user => session[:cas_user])
      end

      def session_expiration_with_cas
        return session_expiration_without_cas unless RedmineCAS.enabled? and RedmineCAS.cas_session_expiry?
        if session[:user_id]
          if session_expired? && !try_to_autologin
            reset_session
          else
            session[:atime] = Time.now.utc.to_i
          end
        end
      end
    end
  end
end
