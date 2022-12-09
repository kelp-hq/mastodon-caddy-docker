
```sh

git clone 
```


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
3. that's it

Now you can start all the containers:

```sh
docker-compose up -d
```





## Backups

Before doing any backups, please open the [.bbackup-and-upload.sh](./backup-and-upload.sh) and edit it according to your needs. 
This will include the bucket name, path where you want your files to be stored and the api where to connect.

The script will automatically load the `.env.production` file and expose the vars to the internal state. If you want to change that
feel free to do so.

The backup script requires following env variables to be set:

- `BACKUP_AWS_ACCESS_KEY_ID` -- minio or aws access key
- `BACKUP_AWS_SECRET_ACCESS_KEY` -- minio or aws secret key
- `DB_PASS` -- postgresql password
- `DB_USER` -- postgresql usename


Cronjob is set to run this once a day at [midnight](https://cron.help/every-day-at-midnight):

```sh

sudo crontab -e

0 0 * * * /path/where/is/the/backup-and-upload.sh

```
