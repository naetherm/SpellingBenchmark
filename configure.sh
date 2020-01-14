#!/bin/bash

if [ $# != 3 ]
then
  echo "You must specify the data path, admin-mail, and admin-password as parameters."
else

  W_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

  data_path=$1

  # First download the archive if not already present
  if [ ! -f $data_path/data.tar.gz ]
  then
    echo "Downloading data.tar.gz from server ..."

    wget -P $data_path http://nsec.informatik.uni-freiburg.de/archive/data.tar.gz
  else
    echo "Archive already present, will skip download."
  fi

  if [ ! -d $data_path/data ]
  then
    echo "Extracting data.tar.gz to $data_path"
    cd $data_path

    tar xzf ./data.tar.gz
  else
    echo "Archive already extracted"
  fi

  cd $W_DIR

  # Set the data path within the docker-compose file
  sed -i "s|@@@DATA_PATH@@@|${data_path}|g" "./docker-compose.yml"

  U_MAIL=$2
  U_PASSWD=$3

  # Set mail and password within frontend/run.sh
  sed -i "s|@@@MAIL@@@|${$U_MAIL}|g" "./frontend/run.sh"
  sed -i "s|@@@PASSWORD@@@|${$U_PASSWD}|g" "./frontend/run.sh"
fi
