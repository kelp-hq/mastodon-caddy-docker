# Mastodon instance with caddy

Hi, you've right decision to move away from the decyaing tech like Twitter. This repo is made to provide easy setup for mastodon instance with automatic TLS.

Default setup consists of these images:

- elasticsearch
- postgres14
- redis
- sidekiq
- mastodon -> the web and main api
- streaming -> Websocket for the dashboard


Additionally this setup works with the [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy), which means that you will get automatic TLS and `reverse_proxy` to both, web and the streaming apis.


Start with cloning the repo: 
```sh
git clone https://github.com/kelp-hq/mastodon-caddy-docker.git 
cd mastodon-caddy-docker
```
This is your starting point for the server setup.

## Server setup

Before you start with anything execute following command:

```sh
touch .env.production
```

This will create empty file for you to update later on and docker will be happy.

Next, is to run the mastodon setup which will ask you some questions about your instance, this will also
create the payload you will need to put in the `.env.production` file.


```sh
# in the root run this and answer the questions
docker-compose run --rm web bundle exec rake mastodon:setup
```

It will ask you to create the admin account, that is not needed since you can always use the cli to set your user to be the `Owner`.

Now it's the time to open the docker-compose file and check the caddy labels. This setup works with the [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy)
and it expects that you already have the `caddy` external network created and the CDP running in other container. 

1. change two occurrances of the `caddy: kelp.community` to your domain
2. make sure that the DNS `@` of your domain is pointing to the server where you will run the instance. If it doesn't the caddy will not be able to issue certificate

Now you can start all the containers:

```sh
docker-compose up -d

# to see the logs, the things are not broken
docker-compose logs -f --tail=100 
```


### Enabling the ElasticSearch

If you are using the default docker-compose, the ES container will start, now we need tell to mastodon server to use it by adding this to the env file:

```ini
ES_ENABLED=true
ES_HOST=es      # docker-service name
ES_PORT=9200    # default port
```

After you have added this you need to recreate the containers, simplest way is to run `docker-compose up -d` which will recreate all the containers that are affected by the env change.



### Enabling Minio or AWS S3

We are running our Minio instances and kelp.community is connected to them. This setup is the same for the AWS S3.

```ini

S3_ENABLED=true
S3_BUCKET=kelp.community                  # set your bucket here
AWS_ACCESS_KEY_ID=my-awesome-access-ky    # Minio Access keys or IAM from AWS
AWS_SECRET_ACCESS_KEY=secret-key          # secret key
S3_ENDPOINT=https://the-s3-endpoint       # you can see this in the AWS or Minio api server (9000)
SE_REGUI=eu-west-1                        # region 
S3_HOSTNAME=s3.aws.hostname               # just the s3 hostname
```

After you have added this you need to recreate the containers, simplest way is to run `docker-compose up -d` which will recreate all the containers that are affected by the env change.

## Backups

Before doing any backups, please open the [.backup-and-upload.sh](./backup-and-upload.sh) and edit it according to your needs. 
This will include the bucket name, path where you want your files to be stored and the api where to connect.

The script will automatically load the `.env.production` file and expose the vars to the internal state. If you want to change that
feel free to do so.

The backup script requires following env variables to be set:

- `BACKUP_AWS_ACCESS_KEY_ID` -- minio or aws access key
- `BACKUP_AWS_SECRET_ACCESS_KEY` -- minio or aws secret key
- `DB_PASS` -- postgresql password
- `DB_USER` -- postgresql username

Cronjob is set to run this once a day at [midnight](https://cron.help/every-day-at-midnight):

```sh
# this doesn't work, need to expose the secrets!
sudo crontab -e
0 0 * * * /path/where/is/the/backup-and-upload.sh

```


## Migration to new server

Follow the official tutorial from [here](https://docs.joinmastodon.org/admin/migrating/) then once you restore DB run this `docker-compose run --rm  web bundle exec rails db:migrate` 

## Resources

- https://ricard.dev/improving-mastodons-disk-usage/
