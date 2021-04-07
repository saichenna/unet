echo "Finished this run"
sleep 10
sync
sh -c 'echo 3 > /proc/sys/vm/drop_caches'
sleep 50
echo " "
