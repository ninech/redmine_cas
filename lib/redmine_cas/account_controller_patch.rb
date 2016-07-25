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
          admingroup_exists = false
          ces_admin_group = `etcdctl --peers $(cat /etc/ces/node_master):4001 get "/config/_global/admin_group"`
          if $?.exitstatus == 0
            admingroup_exists = true
          end

          # Auto-create user
          if user.nil? && RedmineCAS.autocreate_users?
            user = User.new
            user.login = session[:cas_user]
            user.auth_source_id = 1
            user.assign_attributes(RedmineCAS.user_extra_attributes_from_session(session))
            return cas_user_not_created(user) if !user.save
            user.reload

            user = User.find_by_login(session[:cas_user])

            # Auto-create user's groups and/or add him/her
            @usergroups = Array.new
            for i in session[:cas_extra_attributes]
              if i[0]=="allgroups"
                for j in i[1]
                  @usergroups << j
                  begin
                    group = Group.find_by(lastname: j.to_s.downcase)
                    if group.to_s == ""
                      # if group does not exist
                      # create group and add user
                      @newgroup = Group.new(:lastname => j.to_s, :firstname => "cas")
                      @newgroup.users << user
                      @newgroup.save
                    else
                      # if not already: add user to existing group
                      @groupusers = User.active.in_group(group).all()
                      if not(@groupusers.include?(user))
                        group.users << user
                      end
                    end
                  rescue Exception => e
                    logger.info e.message
                  end
                end
                @casgroups = Group.where(firstname: "cas")
                for l in @casgroups
                  @casgroup = Group.find_by(lastname: l.to_s)
                  @casgroupusers = User.active.in_group(@casgroup).all()
                  if @casgroupusers.include?(user) and not(@usergroups.include?(l.to_s))
                    # remove user from group
                    @casgroup.users.delete(user)
                  end
                end
              end
            end
            # Grant admin rights to user if he/she is in ces_admin_group
            if admingroup_exists
              if @usergroups.include?(ces_admin_group.gsub("\n",""))
                user.update_attribute(:admin, 1)
                return cas_user_not_created(user) if !user.save
                user.reload
              end
            end
          end

          return cas_user_not_found if user.nil?
          return cas_account_pending unless user.active?

          user.update_attribute(:last_login_on, Time.now)
          # Change user's admin rights according to cas settings
          @usergroups = Array.new
          for i in session[:cas_extra_attributes]
            if i[0]=="allgroups"
              for j in i[1]
                @usergroups << j
              end
            end
          end
          if admingroup_exists
            if @usergroups.include?(ces_admin_group.gsub("\n",""))
              user.update_attribute(:admin, 1)
              user.save
              user.reload
            else
              user.update_attribute(:admin, 0)
              user.save
              user.reload
            end
          end
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
