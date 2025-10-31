This folder contains Dockerfiles and associated files used during development

- Dockerfile.base - is a configuration used as the base for other images, it contains proper verison of ruby and all 
  required binary dependencies we need to build gems or run app. This image is expected to be published as 
  `damisul/bybe-base:latest`

NOTE: See [Docker Documentation](https://docs.docker.com/get-started/introduction/build-and-push-first-image/) on how 
to push images to Docker Hub.
You'll need to do it every time when debian version or some of dependencies are updated.

## Quick tips
### Building image
```shell
 docker build -t damisul/bybe-base:latest -t damisul/bybe-base:<CUSTOM_TAG> -f Dockerfile.base .
```

### Login in Docker Cli
```shell
 docker login
```

### Pushing image
```shell
 docker push damisul/bybe-base --all-tags
```