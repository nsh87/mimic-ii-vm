jobsrunning=0
maxjobs=9

for ITEM in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 \
    22 23 24 25 26 27 28 29 30 31 32
do
    if [ $jobsrunning -eq $maxjobs ]; then
        jobsrunning=0
        wait
    fi
    jobsrunning=$(( $jobsrunning+1))
    (
    TAR_DIR=/home/vagrant/src/physionet/MIMIC-Importer-2.6/tarballs
    DEST=$TAR_DIR/mimic2cdb-2.6-$ITEM.tar.gz 
    BASE_URL=https://physionet.org/works/MIMICIIClinicalDatabase/files
    URL=$BASE_URL/downloads-2.6/mimic2cdb-2.6-$ITEM.tar.gz
    wget --user $1 --password $2 --continue --no-check-certificate -O $DEST $URL
    ) &
done
