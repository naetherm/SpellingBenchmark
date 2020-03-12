#!/bin/bash

#cd /code/
#echo "Copy data.tar.gz from /data/"
#cp /data/data.tar.gz /code/
#echo "Extracting data.tar.gz to /code/"
#tar xzf ./data.tar.gz
#echo "Investigate structure of /code/data/"
#ls /code/data/
#echo "---"
#ls /code/data/langs/

cd /code/

echo ">> Starting the generation of benchmarks:"
for benchmark in $*
do
  echo -e ">>\t Generate benchmark '$benchmark'"
  ./dgenerator/dgenerator --dataset=wikipedia --seed=1337 --lang_code=en_US --mode=$benchmark --input_dir=/input/ --output_dir=/output/ --data_dir=/data/data/ --format=json --config=dgenerator/configs/lrec.yaml --selfcheck=true
  # --trainingset=true
done
echo "<< Done."

#echo ">> Creating packages for each benchmark:"
#for benchmark in $*
#do
#  echo -e ">>\t Packaging benchmark '$benchmark'"
#  cd /output/$benchmark/
#  for s in raw source groundtruth
#  do
#    if [ ! -f /output/${benchmark}_${s}.tar.gz ]
#    then
#      tar -czf /output/${benchmark}_${s}.tar.gz ./${s}
#      rm -Rf /output/$benchmark/${s}/
#    fi
#  done
#done
#echo "<< Done."
