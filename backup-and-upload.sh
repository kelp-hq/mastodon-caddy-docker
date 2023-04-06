#!/bin/bash
# Adapted from https://gist.github.com/PhilipSchmid/1fd2688ace9f51ecaca2788a91fec133

PROJECT_ROOT=$(git rev-parse --show-toplevel)

function load_dotenv() {
  # https://stackoverflow.com/a/66118031/134904
  source <(cat $1 | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g")
}

set -a
[ -f "$PROJECT_ROOT/.env.production" ] && load_dotenv "$PROJECT_ROOT/.env.production"
set +a

upload_files=${1:-upload}

# minio or aws s3 endpoint
host=files.kelp.digital

# file name which will looke like 2022_01_22_16:21_db_dump.sql:
filename="db_dump.sql"
filename_data_only="db_dump_data_only.sql"
filename_dump_pg_restore="db.dump"

# bucket name
bucket="logs"

# the path where the file is stored
resource_base="/${bucket}/kelp.community_db_dumps/$(date +%F_%R)"
resource="$resource_base/${filename}"
resource_data="$resource_base/${filename_data_only}"
resource_dump_pg_restore="$resource_base/${filename_dump_pg_restore}"

s3_key=$BACKUP_AWS_ACCESS_KEY_ID
s3_secret=$BACKUP_AWS_SECRET_ACCESS_KEY

db_username=$DB_USER
db_password=$DB_PASS
db_name=postgres

# backup the DB
echo "Backing up the DB structure and data as sql..."
docker-compose exec db /bin/bash -c "PGPASSWORD=$DB_PASS pg_dump --username $DB_USER $DB_NAME > /backups/$filename"
echo "Backup successful, file name is $filename"

if [[ "$upload_files" = "upload" ]]; then
  echo "Uploading to $host ..."
  content_type="application/octet-stream"
  date=$(date -R)
  _signature="PUT\n\n${content_type}\n${date}\n${resource}"
  signature=$(echo -en ${_signature} | openssl sha1 -hmac ${s3_secret} -binary | base64)

  curl -X PUT -T "./backups/${filename}" \
    -H "Host: ${host}" \
    -H "Date: ${date}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${s3_key}:${signature}" \
    https://${host}${resource}

  echo "Upload done. removing the file"
  rm -f $filename
fi

echo ""

# backup the DB data only
echo "Backing up the DB data only as sql ..."
docker-compose exec db /bin/bash -c "PGPASSWORD=$DB_PASS pg_dump --data-only --username $DB_USER $DB_NAME > /backups/$filename_data_only"
echo "Backup successful, file name is $filename_data_only"

if [[ "$upload_files" = "upload" ]]; then
  echo "Uploading to $host ..."
  content_type="application/octet-stream"
  date=$(date -R)
  _signature="PUT\n\n${content_type}\n${date}\n${resource_data}"
  signature=$(echo -en ${_signature} | openssl sha1 -hmac ${s3_secret} -binary | base64)

  curl -X PUT -T "./backups/${filename_data_only}" \
    -H "Host: ${host}" \
    -H "Date: ${date}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${s3_key}:${signature}" \
    https://${host}${resource_data}

  echo "Upload done. removing the file"
  rm -f $filename_data_only
fi
echo ""

# backup the DB data only
echo "Backing up the DB data only as .dump ..."

# this needs to be saved to the mounted volume because something happens and docker messes up the non-ASCII bytes
# https://stackoverflow.com/a/63934857/2764898

docker-compose exec db /bin/bash -c "PGPASSWORD=$DB_PASS pg_dump -Fc --username $DB_USER $DB_NAME  > /backups/$filename_dump_pg_restore"
echo "Backup successful, file name is $filename_dump_pg_restore"

if [[ "$upload_files" = "upload" ]]; then
  echo "Uploading to $host ..."
  content_type="application/octet-stream"
  date=$(date -R)
  _signature="PUT\n\n${content_type}\n${date}\n${resource_dump_pg_restore}"
  signature=$(echo -en ${_signature} | openssl sha1 -hmac ${s3_secret} -binary | base64)

  curl -X PUT -T "./backups/${filename_dump_pg_restore}" \
    -H "Host: ${host}" \
    -H "Date: ${date}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${s3_key}:${signature}" \
    https://${host}${resource_dump_pg_restore}

  echo "Upload done. removing the file"
  rm -f $filename_dump_pg_restore
fi
echo "🎉"
