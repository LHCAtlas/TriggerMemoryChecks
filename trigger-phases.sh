#!/bin/sh
# Meant to be run at ATLAS, and on a nightly

release=$1
nightly=$2
events=$3

mydate=`date +"%m-%d-%Y"`

mydesc=${release}.${nightly}.${mydate}.${events}

export AtlasSetup=/afs/cern.ch/atlas/software/dist/AtlasSetup && source /afs/cern.ch/atlas/software/dist/AtlasSetup/scripts/asetup.sh ${release},${nightly},here,gcc48,64

# Get suppressions to try to clean up the valgrind file a little bit
# From http://acode-browser.usatlas.bnl.gov/lxr/source/atlas/Tools/ValgrindRTTJobs/scripts/valgrind_trf.py

get_files newSuppressions.supp
get_files oracleDB.supp
get_files root.supp
get_files valgrindRTT.supp
get_files Gaudi.supp
get_files valgrind-python.supp

# RDO TO ESD STEP
echo ==============================
echo =
echo = RDO to ESD
echo =
echo ==============================
echo == - Config Only
Reco_tf.py --inputRDOFile=/afs/cern.ch/work/l/limosani/public/valid1.117050.PowhegPythia_P2011C_ttbar.recon.RDO.e2658_s1967_s1964_r5787_tid01572821_00/RDO.01572821._000019.pool.root.1  --outputESDFile=myESD.pool.root --preInclude=RecExCommon/ValgrindTweaks.py --maxEvents=${events} --preExec='rec.doTrigger=True;rec.doMonitoring=True' --execOnly  --athenaopts='--config-only=rec.pkl --stdcmalloc' 

echo == - Valgrind Run
valgrind --tool=memcheck --leak-check=full --suppressions=root.supp --suppressions=${ROOTSYS}/etc/valgrind-root.supp --suppressions=newSuppressions.supp --suppressions=oracleDB.supp --suppressions=valgrindRTT.supp --suppressions=Gaudi.supp --suppressions=valgrind-python.supp --num-callers=30 `which python` `which athena.py` rec.pkl >& valgrind.rdotoesd.${mydesc}.log

gzip valgrind.rdotoesd.${mydesc}.log

# ESD TO AOD STEP (with trigger)
echo ==============================
echo =
echo = ESD to AOD
echo =
echo ==============================
echo == - Prep
Reco_tf.py --inputRDOFile=/afs/cern.ch/work/l/limosani/public/valid1.117050.PowhegPythia_P2011C_ttbar.recon.RDO.e2658_s1967_s1964_r5787_tid01572821_00/RDO.01572821._000019.pool.root.1 --outputESDFile=myESD.pool.root --maxEvents=${events} --preExec='rec.doTrigger=True;rec.doMonitoring=False' 

echo == - Config
Reco_tf.py --inputESDFile=myESD.pool.root --outputAODFile=myAOD.pool.root --maxEvents=${events} --preInclude=RecExCommon/ValgrindTweaks.py --maxEvents=${events} --execOnly  --athenaopts='--config-only=rec.pkl --stdcmalloc' 

echo == - Valgrind
valgrind --tool=memcheck --leak-check=full --suppressions=root.supp --suppressions=${ROOTSYS}/etc/valgrind-root.supp --suppressions=newSuppressions.supp --suppressions=oracleDB.supp --suppressions=valgrindRTT.supp --suppressions=Gaudi.supp --suppressions=valgrind-python.supp --num-callers=30 --track-origins=yes `which python` `which athena.py` rec.pkl >& valgrind.esdtoaod.${mydesc}.log

gzip valgrind.esdtoaod.${mydesc}.log

# AOD TO HISTS STEP (NO TRIGGER)
# disabled for now
#Reco_tf.py --inputAODFile=myAOD.pool.root --outputHISTFile=myHIST.pool.root --maxEvents=${events} --preInclude=RecExCommon/ValgrindTweaks.py --execOnly  --athenaopts='--config-only=rec.pkl --stdcmalloc' 

#valgrind --tool=memcheck --leak-check=full --suppressions=root.supp --suppressions=${ROOTSYS}/etc/valgrind-root.supp --suppressions=newSuppressions.supp --suppressions=oracleDB.supp --suppressions=valgrindRTT.supp --suppressions=Gaudi.supp --suppressions=valgrind-python.supp --num-callers=30 --track-origins=yes `which python` `which athena.py` rec.pkl >& valgrind.aodtohists.${mydesc}.out 





