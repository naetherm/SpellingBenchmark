#!/bin/bash

#
# Copy and extract the data.tar.gz file first!
#
#cd /code/
#echo "Copy data.tar.gz from /data/"
#cp /data/data.tar.gz /code/
#echo "Extracting data.tar.gz to /code/"
#tar xzf ./data.tar.gz

#
# Build the generator and create the dataset
#
cd /code/
./devaluator
