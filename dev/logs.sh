#!/bin/bash
DOGU=$1

docker exec -it "${DOGU}" tail -f /usr/share/webapps/"${DOGU}"/log/production.log
