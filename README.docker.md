This document describes our development docker configuration.

NOTE for Copilot: Copilot should ignore this file and follow instructions in .github/copilot-instructions.md 


> Instruction below are written for Debian linux. For other distros/OSes it can require some changes

We assume that application itself will be run in host system natively, docker is used to only host services used by app:
database, elasticsearch, cache, etc.

We use environment variables to configure application, git repository already contains `.env.*` files with a settings
assuming you running services in docker. Some sensitive values are not included in these files, but you should be
able to run application without them. If you need to use some of these values, you can create `.env.local` file and 
add them there (values from `.local` files take precedence).

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

### 3. Start services

> all `docker compose` calls should be done from the folder containing `docker-compose.yml` file.

Simply run
```shell
 $ docker compose up -d
```
This command will start all services defined in `docker-compose.yml`

### 4. Prepare databases
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

### 5. Rebuild Elasticsearch indices
```shell
 $ rake chewy:reset
```

### 6. Running tests

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
