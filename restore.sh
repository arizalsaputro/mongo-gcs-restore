#!/bin/bash

set -o pipefail
set -o errexit
set -o errtrace
set -o nounset
# set -o xtrace


echo "Restore starting..."

BACKUP_DIR=${BACKUP_DIR:-/tmp}
BOTO_CONFIG_PATH=${BOTO_CONFIG_PATH:-/root/.boto}
GCS_BUCKET=${GCS_BUCKET:-}
GCS_KEY_FILE_PATH=${GCS_KEY_FILE_PATH:-}
MONGODB_HOST=${MONGODB_HOST:-localhost}
MONGODB_PORT=${MONGODB_PORT:-27017}
MONGODB_DB=${MONGODB_DB:-}
MONGODB_USER=${MONGODB_USER:-}
MONGODB_PASSWORD=${MONGODB_PASSWORD:-}
MONGODB_OPLOG=${MONGODB_OPLOG:-}
SLACK_ALERTS=${SLACK_ALERTS:-}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-}
SLACK_CHANNEL=${SLACK_CHANNEL:-}
SLACK_USERNAME=${SLACK_USERNAME:-}
SLACK_ICON=${SLACK_ICON:-}
SLACK_ICON_URL=${SLACK_ICON_URL:-}


send_slack_message() {
  local color=${1}
  local title=${2}
  local message=${3}

  echo 'Sending to '${SLACK_CHANNEL}'...'
  curl --silent --data-urlencode \
    "$(printf 'payload={"channel": "%s", "username": "%s", "link_names": "true", "icon_emoji": "%s","icon_url":"%s", "attachments": [{"author_name": "mongodb-gcs-restore", "title": "%s", "text": "%s", "color": "%s"}]}' \
        "${SLACK_CHANNEL}" \
        "${SLACK_USERNAME}" \
        "${SLACK_ICON}" \
        "${SLACK_ICON_URL}" \
        "${title}" \
        "${message}" \
        "${color}" \
    )" \
    ${SLACK_WEBHOOK_URL} || true
  echo
}

restore() {
  cmd_auth_part=""

  if [[ ! -z $MONGODB_USER ]] && [[ ! -z $MONGODB_PASSWORD ]]
  then
    cmd_auth_part="--username=\"$MONGODB_USER\" --password=\"$MONGODB_PASSWORD\""
  fi

  cmd_db_part=""
  if [[ ! -z $MONGODB_DB ]]
  then
    cmd_db_part="--db=\"$MONGODB_DB\""
  fi

  cmd="mongorestore --drop --gzip --archive=$BACKUP_DIR/backup.gz --host=\"$MONGODB_HOST\" --port=\"$MONGODB_PORT\" $cmd_auth_part $cmd_db_part"
  echo "starting to restore MongoDB host=$MONGODB_HOST port=$MONGODB_PORT"
  eval "$cmd"
  send_slack_message "#8e44ad" "Restore Database from GCS" "Success restoring database from google cloud storage"
}

get_from_gcs() {
  echo "$GCS_KEY_FILE_PATH"
  if [[ $GCS_KEY_FILE_PATH != "" ]]
  then
cat <<EOF > $BOTO_CONFIG_PATH
[Credentials]
gs_service_key_file = $GCS_KEY_FILE_PATH
[Boto]
https_validate_certificates = True
[GoogleCompute]
[GSUtil]
content_language = en
default_api_version = 2
[OAuth2]
EOF
  fi
  echo "getting backup archive from GCS bucket=$GCS_BUCKET"
  mkdir -p $BACKUP_DIR
  date=$(date "+%Y-%m-%d")
  archive_name="backup-$date.gz"
  file_backup="$GCS_BUCKET/$archive_name"
  gsutil cp $file_backup $BACKUP_DIR/backup.gz
}

err() {
  err_msg="Something went wrong on line $(caller)"
  echo $err_msg >&2
  if [[ $SLACK_ALERTS == "true" ]]
  then
    send_slack_message "danger" "Error while performing mongodb restore" "$err_msg"
  fi
}

cleanup() {
  rm $BACKUP_DIR/backup.gz
}

trap err ERR
get_from_gcs
restore
cleanup
echo "restore done!"