docker cp app/views/redmine_cas/_settings.html.erb easyredmine:/usr/share/webapps/easyredmine/plugins/redmine_cas/app/views/redmine_cas/
docker cp config/locales/en.yml easyredmine:/usr/share/webapps/easyredmine/plugins/redmine_cas/config/locales/en.yml
docker cp lib/redmine_cas/account_controller_patch.rb easyredmine:/usr/share/webapps/easyredmine/plugins/redmine_cas/lib/redmine_cas/account_controller_patch.rb
docker cp lib/redmine_cas/application_controller_patch.rb easyredmine:/usr/share/webapps/easyredmine/plugins/redmine_cas/lib/redmine_cas/application_controller_patch.rb
docker restart easyredmine
watch 'docker ps |grep "easy"'
