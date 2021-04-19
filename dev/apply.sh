#!/bin/bash
DOGU=$1

docker cp ../app/views/redmine_cas/_settings.html.erb "${DOGU}":/usr/share/webapps/"${DOGU}"/plugins/redmine_cas/app/views/redmine_cas/
docker cp ../app/models "${DOGU}":/usr/share/webapps/"${DOGU}"/plugins/redmine_cas/app/models
docker cp ../config/locales/en.yml "${DOGU}":/usr/share/webapps/"${DOGU}"/plugins/redmine_cas/config/locales/en.yml
docker cp ../lib/redmine_cas/account_controller_patch.rb "${DOGU}":/usr/share/webapps/"${DOGU}"/plugins/redmine_cas/lib/redmine_cas/account_controller_patch.rb
docker cp ../lib/redmine_cas/application_controller_patch.rb "${DOGU}":/usr/share/webapps/"${DOGU}"/plugins/redmine_cas/lib/redmine_cas/application_controller_patch.rb
docker restart "${DOGU}"
watch "docker ps |grep ${DOGU}"
