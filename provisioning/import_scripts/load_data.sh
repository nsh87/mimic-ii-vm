#!/usr/bin/env bash

if [ "$1" = "all" ]
then
    END=99999
else
    END=$1
fi

START=0
COUNTER=0 # Number of records loaded

FIRST=`printf %05d $START`
LAST=`printf %05d $END`
ABS_LAST=$((10#$LAST)) # For comparison with counter (no leading 0's)

echo "Subject IDs between $FIRST and $LAST will be processed."

BK=0 # Break out of unzipping if equal 1

# Load the subject-specific data
for NN in 00 01 02 03 04 05 06 07 08 09 \
          10 11 12 13 14 15 16 17 18 19 \
          20 21 22 23 24 25 26 27 28 29 \
          30 31 32
do
    TFIRST=${NN}000
    TLAST=${NN}999
    if [[ $TLAST < $FIRST || $TFIRST > $LAST ]]
    then
        continue; # this set does not include any subjects of interest
    fi

    UNZIP_PATH=/home/vagrant/src/physionet/MIMIC-Importer-2.6/raw_tarballs
    TAR_PATH=/home/vagrant/src/physionet/MIMIC-Importer-2.6/tarballs
    TARBALL=$TAR_PATH/mimic2cdb-2.6-${NN}.tar
    if [[ -s $TARBALL.gz && "$BK" -ne 1 ]]
    then
        echo "Unpacking ${TARBALL} ..."
        tar xfz $TARBALL.gz -C $UNZIP_PATH
    elif [[ -s $TARBALL && "$BK" -ne 1 ]]
    then
    echo
        "Unpacking ${TARBALL} ..."
        tar xf $TARBALL -C $UNZIP_PATH
    fi

    if [[ ! -d $UNZIP_PATH/$NN && "$BK" -ne 1 ]]
        then
        echo "Warning: set ${NN} not available"
        continue; # this set is not available
    fi

    if [ "$BK" -ne 1 ]; then
        cd $UNZIP_PATH/$NN
        TMP_N=`find . -maxdepth 1 -type d | wc -l`
        echo Processing set ${NN} with $(( ${TMP_N}-1 )) subjects at `date`
        jobsrunning=0
        maxjobs=2
        for ID in ?????
        do
            if [ $jobsrunning -eq $maxjobs ]; then
                jobsrunning=0
                wait
            fi
            jobsrunning=$(( $jobsrunning+1 ))
            # need to force base 10 to compare the integers below
            if [ $COUNTER -lt $ABS_LAST ]; then
                for TAB in D_PATIENTS ADMISSIONS ICUSTAYEVENTS \
                A_CHARTDURATIONS CENSUSEVENTS MEDEVENTS ADDITIVES \
                CHARTEVENTS NOTEEVENTS DELIVERIES POE_ORDER POE_MED \
                A_IODURATIONS IOEVENTS A_MEDDURATIONS ICD9 LABEVENTS \
                TOTALBALEVENTS DRGEVENTS MICROBIOLOGYEVENTS DEMOGRAPHICEVENTS \
                PROCEDUREEVENTS ICUSTAY_DAYS ICUSTAY_DETAIL \
                COMORBIDITY_SCORES DEMOGRAPHIC_DETAIL
                do
                    TF=$PWD/$ID/${TAB}-$ID.txt
                    if [ -d "$PWD/$ID/" -a -s $TF ]; then
                        echo "COPY MIMIC2V26.$TAB FROM '$TF' WITH DELIMITER E',' CSV HEADER;" | psql MIMIC2 -q -f -
                    fi
                done
                # remove each subject flat file when no longer needed
                rm -rf $PWD/$ID
                COUNTER=$((COUNTER+1))
            else
                BK=1 # Break unzipping tarballs
            fi
        done
        cd ..
        LOADED=`psql MIMIC2 -tc "select count(distinct(subject_id)) from mimic2v26.d_patients;"`
        echo "Total subjects added: $LOADED for batch $NN at `date`"
    fi
done

echo "Creating the indices at `date`"
IND=/home/vagrant/src/physionet/MIMIC-Importer-2.6/Definitions/POSTGRES
psql MIMIC2 -q -f $IND/indices_mimic2v26.sql

echo "***Done creating the MIMIC II Database at `date`***"
