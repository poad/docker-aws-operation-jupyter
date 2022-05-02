# docker-aws-operation-jupyter

## Usage

```sh
TAG=jammy
docker run -p 8888:8888 -v $HOME/.aws:/home/jupyter/.aws:ro --name jupyter -d poad/docker-aws-operation-jupyter:${TAG}
docker logs jupyter
```

### with node modules

```sh
# in terminal on Jupyter
yarn install
# yarn add package
```

```typescript
import pkg from 'added package';
```
