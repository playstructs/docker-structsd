# docker-structsd

[Docker](https://www.docker.com) container for running the [Structs Consensus Engine](https://github.com/playstructs/structsd/). 

Docker Hub: [https://hub.docker.com/r/structs/structsd/](https://hub.docker.com/r/structs/structsd/)

## Structs
In the distant future the species of the galaxy are embroiled in a race for Alpha Matter, the rare and dangerous substance that fuels galactic civilization. Players take command of Structs, a race of sentient machines, and must forge alliances, conquer enemies and expand their influence to control Alpha Matter and the fate of the galaxy.

# How to Build

```
git clone git@github.com:playstructs/docker-structsd.git
cd docker-structsd
docker build .
```

# How to Use this Image

## Quickstart

The following will run the latest Structs postgres database server.

```
docker run -d --rm -p 26656:26656 --name=structsd structs/structsd:latest
```

## Interactive

A good way to run for development and for continual monitoring is to attach to the terminal:

```
docker run -it --rm -p 26656:26656 --name=structsd structs/structsd:latest
```

# Learn more

- [Structs](https://playstructs.com)
- [Project Wiki](https://watt.wiki)
- [@PlayStructs Twitter](https://twitter.com/playstructs)


# License

Copyright 2021 [Slow Ninja Inc](https://slow.ninja).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.