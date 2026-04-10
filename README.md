DEPRECATED: the orchestrator is split into dedicated services: 

- darc-code: the vscode server container
- compose server: the docker compose server for interacting with docker
- darc-worker: the main daemon process for darc
- docker-proxy: minimal CONNECT proxy for reaching docker containers without manual port mapping, counter part to the dev router that is part of darc-worker
