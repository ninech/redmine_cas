require 'redmine_cas'

module RedmineCAS
  module AccountControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :logout_without_cas, :logout
        alias_method :logout, :logout_with_cas
        alias_method :original_login, :login
        alias_method :login, :cas_login
      end
    end

    module InstanceMethods
      def cas_login
        return original_login unless RedmineCAS.enabled?
        HOME_URL = "tbd"
        CAS_URL = "/cas/login"

        prev_url = request.referrer
        prev_url = home_url if prev_url.to_s.strip.empty?

        login_url = cas_url + "?service=" + ERB::Util.url_encode(prev_url)
        redirect_to login_url
      end

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
          ces_admin_group = ENV['ADMIN_GROUP']
          admingroup_exists = ces_admin_group != nil

          # Auto-create user
          if user.nil? && RedmineCAS.autocreate_users?
            user = User.new
            user.login = session[:cas_user]
            user.auth_source_id = 1
            user.assign_attributes(RedmineCAS.user_extra_attributes_from_session(session))
            return cas_user_not_created(user) if !user.save
            user.reload
          else
            user = User.find_by_login(session[:cas_user])
          end

          # Auto-create user's groups and/or add him/her
          @usergroups = Array.new
          for i in session[:cas_extra_attributes]
            if i[0]=="allgroups"
              for j in i[1]
                @usergroups << j
                begin
                  group = Group.find_by(lastname: j.to_s)
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
          # Revoke admin rights if they were granted by cas and not granted from a redmine administrator
          if admingroup_exists
            # Get custom field which indicates if the admin permissions of the user were set via cas
            casAdminPermissionsCustomField = UserCustomField.find_by_name('casAdmin')
            # Create custom field if it doesn't exist yet
            if casAdminPermissionsCustomField == nil
              casAdminPermissionsCustomField = UserCustomField.new
              casAdminPermissionsCustomField.field_format = 'bool'
              casAdminPermissionsCustomField.name = 'casAdmin'
              casAdminPermissionsCustomField.description = 'Indicates if admin permissions were granted via cas; do not delete!'
              casAdminPermissionsCustomField.visible = false
              casAdminPermissionsCustomField.editable = false
              casAdminPermissionsCustomField.validate_custom_field
              casAdminPermissionsCustomField.save!
            end

            if @usergroups.include?(ces_admin_group.gsub("\n",""))
              user.update_attribute(:admin, 1)
              user.custom_field_values.each do |field|
                if field.custom_field.name == 'casAdmin'
                  field.value = true
                end
              end
              return cas_user_not_created(user) if !user.save
              user.reload
            else
              # Only revoke admin permissions if they were set via cas
              if user.custom_field_value(casAdminPermissionsCustomField).to_s == 'true'
                user.update_attribute(:admin, 0)
              end
              user.custom_field_values.each do |field|
                if field.custom_field.name == 'casAdmin'
                  field.value = false
                end
              end
              return cas_user_not_created(user) if !user.save
              user.reload
            end
            casAdminPermissionsCustomField.validate_custom_field
            casAdminPermissionsCustomField.save!
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
        default_url = url_for(params.permit(:ticket).merge(:ticket => nil))
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
