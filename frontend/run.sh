#!/bin/bash

sleep 10
cd /code/benchmark
python3 manage.py makemigrations
python3 manage.py makemigrations workbench
python3 manage.py migrate
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'naether.markus@gmail.com', 'leave4ever')" | python3 manage.py shell
python3 manage.py loaddata fixtures/startup.json
#export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"

python3 manage.py runserver 0.0.0.0:8000
