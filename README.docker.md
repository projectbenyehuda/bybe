This document describes our development docker configuration.

> Instruction below are written for Debian linux. For other distros/OSes it can require some changes

We assume that application itself will be run in host system natively, docker is used to only host services used by app:
database, elasticsearch, cache, etc.

In some sitations (e.g. when working with CodePilot) we may need an ability to run tests on application. To simplify
this `docker-compose.yml` declares special service `test-app`

So to run all specs in application you may use command:
```shell
docker compose run --rm test-app
```

Or to run specific spec:
```shell
docker compose run --rm test-app rspec <PATH_TO_SPEC>
```

## Preparing development environment with docker

### 1. Installing docker
Don't use docker packages shipped with your distro. Install docker, as described on [official website](https://docs.docker.com/engine/install/debian/).

Next create a group named docker:
```shell
 $ sudo groupadd docker
```

Add your user to this group:
```shell
 $ sudo usermod -aG docker $USER
```

As an optional step, you can configure docker to start as a service, so all services will be up and running right after
reboot. To do so just run:
```shell
 $ sudo systemctl enable docker.service
 $ sudo systemctl enable containerd.service
```

You'll need to re-login to apply those changes. Afterwards you'll be able to run docker commands without using `sudo/su`.

### 2. Updating memory preferences

In order to use elasticsearch with docker we need to update vm memory preferences, so open as root `/etc/sysctl.conf`
and add there a line:
```
vm.max_map_count=262144
```

### 3. Update configuration files

To use docker-magaed services you need to update set of configuration files in `config` folder:
- `constants.yml` and `storage.yml` - simply copy content of `constants.yml.sample` and `storage.yml.sample`
- `s3.yml` - you can copy content of `s3.yml.sample` but to have images properly loaded you'll need real keys for our server. 

### 4. Start services

> all `docker compose` calls should be done from the folder containing `docker-compose.yml` file.

Simply run
```shell
 $ docker compose up -d
```
This command will start all services defined in `docker-compose.yml`

### 5. Prepare databases
At first you need to create databases:
```shell
 $ rails db:create
```

You'll probably want to use snapshot of production db for development. So you need to restore it from dump:
```shell
 $ cat <PATH_TO_DUMP_FILE> | docker exec -i bybeconv-mysql-1 mysql -u root --password=root bybe_dev
```

Now we need to migrate this db:
```shell
 $ rails db:migrate
```
And migrate test database as well:
```shell
 $ rails db:migrate RAILS_ENV=test
```

### 6. Rebuild Elasticsearch indices
```shell
 $ rake chewy:reset
```

### 7. Running tests

Now you can try to run specs to check your setup 
```shell
 $ rspec
```

## Useful hints

### Starting and stopping containers

To create and start containers defined in `docker-compose.yml` file simply run:
```shell
 $ docker compose up -d
```

If you have changed docker images config you may need to provide additional keys to force image rebuild:
```shell
 $ docker compose up --build -d 
```

To stop containers temporarily run:
```shell
 $ docker compose stop
```

To start stopped containers run:
```shell
 $ docker compose start
```

To stop and remove all containers
```shell
 $ docker compose down
```

If you also want to remove all volumes used by containers, add `-v' key:
```shell
 $ docker compose down -v
```
NOTE: this will remove all database and elastic search data, so you'll need to recreate them on a next start.

### Creating DB dump
```shell
 $ docker exec bybeconv-mysql-1 mysqldump -u root --password=root <DB_NAME> | cat > <PATH_TO_DUMP_FILE>
```

### Restoring DB dump

```shell
 $ cat <PATH_TO_DUMP_FILE> | docker exec -i bybeconv-mysql-1 mysql -u root --password=root <DB_NAME>
```
