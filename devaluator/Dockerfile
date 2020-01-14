# Copyright 2019, University of Freiburg.
# Chair of Algorithms and Data Structures.
# Markus Näther <naetherm@informatik.uni-freiburg.de>

FROM dlang2/dmd-ubuntu:latest

MAINTAINER "Markus 'naetherm' Näther <naetherm@informatik.uni-freiburg.de>"
# Copy files
RUN mkdir -p /code/devaluator && mkdir -p /code/dutility
#RUN mkdir /data/
WORKDIR /code/devaluator
COPY ./devaluator /code/devaluator
COPY ./dutility /code/dutility

# Volumes
VOLUME /input/ /output/ /data/

# First, compile the generator  --build=release
RUN dub build --build=debug --parallel devaluator

EXPOSE 1338

# The command that should be executed when running the container
ENTRYPOINT ["/code/devaluator/devaluator"]
#CMD ["/code/devaluator"]
