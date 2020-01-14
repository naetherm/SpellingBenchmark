# Copyright 2019, University of Freiburg.
# Chair of Algorithms and Data Structures.
# Markus Näther <naetherm@informatik.uni-freiburg.de>

FROM python:3.7-stretch

MAINTAINER "Markus Näther <naetherm@informatik.uni-freiburg.de>"

RUN apt update && apt install -y php sqlite3 enchant aspell libaspell-dev build-essential python3-dev libhunspell-dev hunspell hunspell-en-us php-curl swig3.0
RUN pip3 install html5lib Django django-bootstrap4 celery requests psycopg2 numpy grammarbot
RUN pip3 install nltk ujson pyenchant pylanguagetool regex aspell-python-py3 hunspell


RUN mkdir /code/
COPY . /code/
WORKDIR /code/benchmark/

#ENTRYPOINT ["python3"]
#CMD ["manage.py", "runserver", "0.0.0.0:8000"]
ENTRYPOINT ["/bin/bash"]
CMD ["/code/run.sh"]
