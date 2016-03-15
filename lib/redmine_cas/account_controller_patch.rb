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

      def cas
        return redirect_to_action('login') unless RedmineCAS.enabled?

        if User.current.logged?
          # User already logged in.
          redirect_to_ref_or_default
          return
        end

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

          # Auto-create user's groups and/or add him/her
          @usergroups = Array.new
          for i in session[:cas_extra_attributes]
            if i[0]=="allgroups"
              for j in i[1]
                @usergroups << j
                begin
                  group = Group.find_by(lastname: j.to_s.downcase)
                  if group.to_s == ""
                    # create group and add user
                    @newgroup = Group.new(:lastname => j.to_s, :firstname => "cas")
                    @newgroup.users << user
                    @newgroup.save
                  else
                    # if not already: add user to existing group
                    @users = User.active.in_group(group).all()
                    if @users.include?(user)
                      logger.info "DEBUG: user "+user.to_s
                      logger.info "DEBUG: ...is already in group "+group.to_s
                    else
                      logger.info "DEBUG: user "+user.to_s
                      logger.info "DEBUG: ...is not in group "+group.to_s
                      logger.info "DEBUG: insert user into group "+group.to_s
                      group.users << user
                    end
                  end
                rescue Exception => e
                  logger.info e.message
                end
              end
              #logger.info "DEBUG: usergroups: "+@usergroups.to_s
              @casgroups = Group.where(firstname: "cas")
              for l in @casgroups
                logger.info "DEBUG: casgroup: "+l.to_s
                if not(@usergroups.include?(l.to_s))
                  logger.info "DEBUG: not in usergroups: "+l.to_s
                  logger.info "DEBUG: usergroups: "+@usergroups.to_s
                  @casgroup = Group.find_by(lastname: l.to_s)
                  # remove user from group

                  logger.info "DEBUG: casgroup: "+@casgroup.to_s
                  # remove group if empty
                  for m in @users
                    logger.info "DEBUG: user in group: "+m.to_s
                  end
                  logger.info "DEBUG: "
                end
              end
            end
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

          redirect_to_ref_or_default
        end
      end

      def redirect_to_ref_or_default
        default_url = url_for(params.merge(:ticket => nil))
        if params.has_key?(:ref)
          # do some basic validation on ref, to prevent a malicious link to redirect
          # to another site.
          new_url = params[:ref]
          if /http(s)?:\/\/|@/ =~ new_url
            # evil referrer!
            redirect_to default_url
          else
            redirect_to request.base_url + params[:ref]
          end
        else
          redirect_to default_url
        end
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

    end
  end
end
