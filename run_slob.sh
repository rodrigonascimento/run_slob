#!/bin/bash

# -- run_slob.sh --------------------------------------------------------------
# 
# $1 == SLOB run time in seconds per lap
# $2 == Testing type [ linux_nfs, dnfs, asm_dnfs ]
# $3 == RUN Name. e.g. RUN001 
# $4 == Number of laps
#
# Example: $ ./run_slob 600 dnfs RUN003 7
# 
# Run slob for 10 min/lap with a total of 7 laps. 
# Store the results on TESTRUNS/dnfs/RUN003
# 
# -----------------------------------------------------------------------------

# -- Variable Definitions -----------------------------------------------------
SLOB_HOME="/home/oracle/SLOB"
RESULTS_HOME="${SLOB_HOME}/TESTRUNS/"

LAP_RUN_TIME=${1}
TEST_TYPE=${2}
RUN_NAME=${3}
MAX_LAPS=${4}

NUM_THREADS=1
LAP=1

# -- Functions ----------------------------------------------------------------
function f_edit_slob_conf() {
  local VAR_LOOKUP=${1}
  local VAR_NEW_VALUE=${2}

  OLD_VAR=$(grep ^${VAR_LOOKUP} ${SLOB_HOME}/slob.conf)
  OLD_VAR_NAME=$(echo ${OLD_VAR} | awk -F"=" '{ print $1 }')
  OLD_VAR_VALUE=$(echo ${OLD_VAR} | awk -F"=" '{ print $2 }')

  sed -i "s/^${OLD_VAR}/${OLD_VAR_NAME}=${VAR_NEW_VALUE}/" ${SLOB_HOME}/slob.conf
}

function f_create_dirs() {
  if [ ! -d ${RESULTS_HOME} ]
  then
    mkdir -p ${RESULTS_HOME}
  fi

  if [ ! -d ${RESULTS_HOME}/${TEST_TYPE} ]
  then
    mkdir -p ${RESULTS_HOME}/${TEST_TYPE}
  fi 

  if [ ! -d ${RESULTS_HOME}/${TEST_TYPE}/${RUN_NAME} ]
  then
    mkdir -p  ${RESULTS_HOME}/${TEST_TYPE}/${RUN_NAME}
  fi
}

# -- Main body ----------------------------------------------------------------

f_create_dirs

RUN_HOME=${RESULTS_HOME}/${TEST_TYPE}/${RUN_NAME}

f_edit_slob_conf "RUN_TIME" ${LAP_RUN_TIME}
f_edit_slob_conf "THREADS_PER_SCHEMA" ${NUM_THREADS}

while [ ${LAP} -le ${MAX_LAPS} ]
do
  
  SLOB_CONF_NUM_THREADS=$(grep ^THREADS_PER_SCHEMA ${SLOB_HOME}/slob.conf | awk -F"=" '{ print $2 }')
  if [ ${SLOB_CONF_NUM_THREADS} != ${NUM_THREADS} ]
  then
    f_edit_slob_conf "THREADS_PER_SCHEMA" ${NUM_THREADS}
  fi 

  echo "Running at ${NUM_THREADS}..."
  ${SLOB_HOME}/runit.sh 4 
  sleep 3

  echo "Saving results..."
  mv ${SLOB_HOME}/awr.txt ${RUN_HOME}/lap0${LAP}.awr.04users.0${NUM_THREADS}threads.txt 
  mv ${SLOB_HOME}/mpstat.out ${RUN_HOME}/lap0${LAP}.mpstat.04users.0${NUM_THREADS}threads.out
  mv ${SLOB_HOME}/vmstat.out ${RUN_HOME}/lap0${LAP}.vmstat.04users.0${NUM_THREADS}threads.out
  mv ${SLOB_HOME}/iostat.out ${RUN_HOME}/lap0${LAP}.nfsiostat.04users.0${NUM_THREADS}threads.out

  echo "Taking a 120 seconds nap before next lap..."
  sleep 120

  NUM_THREADS=$(( NUM_THREADS * 2 ))
  LAP=$(( LAP + 1 ))
done
