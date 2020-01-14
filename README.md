# SpellingBenchmark

This repository contains all related code for our spelling error correction benchmark, including the evaluator source code as well as the web frontend we've used for visualisation.

## Setup

You will require the following software: ```docker, docker-compose```.

## Configure

Before you can start the docker containers you have to do the following two steps:
 - Download the required data
 - Specify the directory where the data is placed within the ```docker-compose.yml``` file

The best way to do that is using the provided ```configure.sh``` script which requires three parameters.
 - The first one is the data directory were to download the required language information and benchmark data
 - The second one is the admin mail and the third one the password which will be used for the creation of the web frontend

After that, simply build and start all required containers:

```
docker-compose build
docker-compose up
```
