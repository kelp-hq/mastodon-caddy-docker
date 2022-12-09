#!/bin/bash
# Adapted from https://gist.github.com/PhilipSchmid/1fd2688ace9f51ecaca2788a91fec133

PROJECT_ROOT=$(git rev-parse --show-toplevel)

function load_dotenv(){
  # https://stackoverflow.com/a/66118031/134904
  source <(cat $1 | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g")
}

set -a
[ -f "$PROJECT_ROOT/.env.production" ] && load_dotenv "$PROJECT_ROOT/.env.production"
set +a

# minio or aws s3 endpoint
host=files.kelp.digital

# file name which will looke like 2022_01_22_16:21_db_dump.sql:
filename="$(date +%F_%R)_db_dump.sql"

# bucket name
bucket="logs"

# the path where the file is stored
resource="/${bucket}/kelp.community_db_dumps/${filename}"

s3_key=$BACKUP_AWS_ACCESS_KEY_ID
s3_secret=$BACKUP_AWS_SECRET_ACCESS_KEY

db_username=$DB_USER
db_password=$DB_PASS
db_name=postgres


# backup the DB
echo "Backing up the DB ..."
docker-compose exec db /bin/bash -c "PGPASSWORD=$DB_PASS pg_dump --username $DB_USER $DB_NAME" > $filename
echo "Backup successful, file name is $filename"


echo "Uploading to $host ..."
content_type="application/octet-stream"
date=`date -R`
_signature="PUT\n\n${content_type}\n${date}\n${resource}"
signature=`echo -en ${_signature} | openssl sha1 -hmac ${s3_secret} -binary | base64`

curl -X PUT -T "${filename}" \
          -H "Host: ${host}" \
          -H "Date: ${date}" \
          -H "Content-Type: ${content_type}" \
          -H "Authorization: AWS ${s3_key}:${signature}" \
          https://${host}${resource}

echo "Upload done. removing the file"
rm -f $filename

echo "🎉"
