This folder contains Dockerfiles and associated files used during development

- Dockerfile.base - is a configuration used as the base for other images, it contains proper verison of ruby and all 
  required binary dependencies we need to build gems or run app. This image is expected to be published as 
  `damisul/bybe-base:latest`
- Dockerfile.test - is a configuration used by test-app service in our `docker-compose.yml` (used to run specs by 
  Copilot in GitHub Codespaces)

NOTE: See [Docker Documentation](https://docs.docker.com/get-started/introduction/build-and-push-first-image/) on how 
to push images to Docker Hub.
You'll need to do it every time when ruby version or binary dependencies are changed.