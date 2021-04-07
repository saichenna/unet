#!/bin/bash

var1="worker1"

patch_dim=32

echo "Image dimension: ${patch_dim}x${patch_dim}x${patch_dim} " > tmp.log3
root=`pwd`/performance_logs
cd $root
ls -a

time_stamp=$(date +%Y_%m_%d_%H_%M_%S)
mkdir -p "${root}/${time_stamp}"

cd $root
ls -a

a_list="1 2 3 4"

echo $a_list
b=""
for a in $a_list
do
	b+=$a
	b+=$'\n'	
	echo $a
done

echo $b
tmp=0
zero=0
if (( $tmp == 0 )); then
	echo "Something wrong!"
else
	echo "Success!"
fi

cd `pwd`/worker1
ls

