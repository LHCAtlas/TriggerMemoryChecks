#!/bin/env bash
# Notes:
#  -> The release this runs against is out of afs, so you will have to be somewhere
#  where CERN's afs is availible.
#  -> A checkout occurs for PyTools, so you'll
#     need to make sure you have a credential for this.
#

release=$1
nightly=$2
events=$3
packages=$4

mydate=`date +"%m-%d-%Y"`

mydesc=${release}.${nightly}.${mydate}.${events}

# Setup the release
export AtlasSetup=/afs/cern.ch/atlas/software/dist/AtlasSetup 
source /afs/cern.ch/atlas/software/dist/AtlasSetup/scripts/asetup.sh ${release},${nightly},here,gcc48,64

# If there are any packages we need to check out, then we need to do that now.
for pkg in $packages
do
  pkgco.py $pkg
done
for pkg in $packages
do
  idx=`expr index $pkg "-"`
  pName=${pkg:0:$idx-1}
  loc=`find . -name $pName -print`
  pushd $loc
  cd cmt
  ls
  source setup.sh
  cmt broad make
  popd
done

# Get the trigger test setup. Do this only if the run hasn't been
# done up to now.
test=ElectronSliceAthenaTrigRDO_MC
if [ ! -d "$test" ]; then
  echo ==============================
  echo =
  echo = Setup
  echo =
  echo ==============================
  echo "Running trigtest to get everything configured"
  trigtest.pl --test $test --run $test --conf TriggerTest.conf

  # Get suppressions to try to clean up the valgrind file a little bit
  # From http://acode-browser.usatlas.bnl.gov/lxr/source/atlas/Tools/ValgrindRTTJobs/scripts/valgrind_trf.py

  get_files newSuppressions.supp
  get_files oracleDB.supp
  get_files root.supp
  get_files valgrindRTT.supp
  get_files Gaudi.supp
  get_files valgrind-python.supp
fi

# Get back into the directory
cd $test

# Setup for the job to run
cp ../$test-jobOptions.py jobOptions.py

# Make the pickle file...
athena.py --config-only=valgrind.pkl --preInclude=RecExCommon/ValgrindTweaks.py jobOptions.py

# finally run the valgrind job.
echo ==============================
echo =
echo = valgrind
echo =
echo ==============================
echo "Now going to run valgrind"
valgrind --leak-check=full --trace-children=yes --num-callers=30 \
    --show-reachable=yes --track-origins=yes \
    --suppressions=$ROOTSYS/etc/valgrind-root.supp \
    --suppressions=/afs/cern.ch/user/k/krasznaa/public/valgrind/newSuppressions.supp \
    --suppressions=/afs/cern.ch/user/k/krasznaa/public/valgrind/oracleDB.supp \
    --suppressions=/afs/cern.ch/user/k/krasznaa/public/valgrind/valgrindRTT.supp \
    --suppressions=/afs/cern.ch/user/k/krasznaa/public/valgrind/pythonJobO.supp \
    --suppressions=/afs/cern.ch/user/k/krasznaa/public/valgrind/reflexPyROOT.supp \
    --error-limit=no `which athena.py`  -c 'EvtMax=$events;enableCostMonitoring = False; RunningRTT=TRUE;menu="MC_pp_v5_tight_mc_prescale"; sliceName="egamma";jp.Rec.OutputLevel=WARNING;LVL1OutputLevel=WARNING;HLTOutputLevel=WARNING;dsName="/eos/atlas/atlascerngroupdisk/trig-daq/validation/test_data/valid1.117050.PowhegPythia_P2011C_ttbar.merge.HITS.e2658_s1967_s1964";fileRange=[32,32];--maxEvents=${events}' --stdcmalloc \
    valgrind.pkl 2>&1 | tee ../valgrind.$test.$mydesc.log
