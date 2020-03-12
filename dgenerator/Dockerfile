# Copyright 2019, University of Freiburg.
# Chair of Algorithms and Data Structures.
# Markus Näther <naetherm@informatik.uni-freiburg.de>

FROM dlang2/ldc-ubuntu:latest

MAINTAINER "Markus 'naetherm' Näther <naetherm@informatik.uni-freiburg.de>"

# Just to be sure install tar
RUN apt install -y tar

# Copy files
#RUN mkdir -p /code/dgenerator && mkdir -p /code/dgenerator
##RUN mkdir /data/
#WORKDIR /code/dgenerator
#COPY ./dgenerator /code/dgenerator
#COPY ./dutility /code/dutility
RUN mkdir /code/
#RUN mkdir /data/
WORKDIR /code/
COPY . /code/
WORKDIR /code/dgenerator

# Volumes
VOLUME /input/ /output/ /data/

# First, compile the generator
# --build=release  --compiler=ldc2 --parallel
RUN dub build --build=debug dgenerator

ENTRYPOINT ["/bin/bash"]
CMD ["./run_generation.sh", "smallish_benchmark", "tiny_benchmark", "medium_benchmark"]
#, "tiny_benchmark", "medium_benchmark"]
