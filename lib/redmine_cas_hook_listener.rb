module RedmineCAS
  class RedmineCASHookListener < Redmine::Hook::ViewListener
    render_on :view_account_login_top, :partial => 'redmine_cas/cas_login_link'
  end
end
