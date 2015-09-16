for DFILE in /home/vagrant/src/physionet/MIMIC-Importer-2.6/Definitions/*.txt
do
    DEF=`basename $DFILE .txt`
    echo $DEF
    SQL_CMD="COPY mimic2v26.$DEF FROM '$DFILE' WITH DELIMITER E',' \
             CSV HEADER;"
    psql MIMIC2 -q -c "$SQL_CMD"
done
