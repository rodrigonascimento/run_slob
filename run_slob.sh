#!/bin/bash

# -- run_slob.sh --------------------------------------------------------------
# 
# -tm == SLOB run time in seconds per lap
# -tt == Testing type [ linux_nfs, dnfs, asm_dnfs ]
# -rn == RUN Name. e.g. RUN001 
# -nl == Number of laps
# -anfquota == ANF Quota
# -rac == Oracle RAC
#
# Example 1: $ ./run_slob -tm 600 -tt dnfs -rn RUN003 -nl 7 -anfquota 4TB
# Example 2: $ ./run_slob -tm 600 -tt dnfs -rn RUN003 -nl 7 -rac
# 
# Run slob for 10 min/lap with a total of 7 laps. 
# Store the results on TESTRUNS/dnfs/RUN003
# 
# -----------------------------------------------------------------------------

# -- Variable Definitions -----------------------------------------------------
SLOB_HOME="/home/oracle/SLOB"
RESULTS_HOME="${SLOB_HOME}/TESTRUNS/"
NUM_THREADS=1
LAP=1

# -- Functions ----------------------------------------------------------------
function f_arg_parser() {
  if [ ${1} != "-tm" ]
  then
    echo "Positional argument different than -tm"
    exit 1
  else
    LAP_RUN_TIME=${2}
  fi
  
  if [ ${3} != "-tt" ]
  then
    echo "Positional argument different than -tt"
    exit 1
  else
    TEST_TYPE=${4}
  fi

  if [ ${5} != "-rn" ]
  then
    echo "Positional argument different than -rn"
    exit 1
  else
    RUN_NAME=${6}
  fi

  if [ ${7} != "-nl" ]
  then
    echo "Positional argument different than -nl"
    exit 1
  else
    MAX_LAPS=${8}
  fi

  if [ ${9} != "-inct" ]
  then
    echo "Positional argument different than -inct"
    exit 1
  else
    INC_THREAD_BY=${10}
  fi

  if [ ${11} = "-anfquota" ]
  then
    RAC=0
    ANF_QUOTA=${12}
  elif [ ${11} = "-rac" ]
  then
    RAC=1
  else
    echo "Positional argument different than -anfquota or -rac: ${11}"
    exit 1
  fi
}

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

f_arg_parser ${1} ${2} ${3} ${4} ${5} ${6} ${7} ${8} ${9} ${10} ${11} ${12}

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
  echo "LAP_RUN_TIME = ${LAP_RUN_TIME}"
  echo "TEST_YTPE = ${TEST_TYPE}"
  echo "RUN_NAME = ${RUN_NAME}"
  echo "MAX_LAPS = ${MAX_LAPS}"
  echo "INC_THREAD_BY = ${INC_THREAD_BY}"
  ${SLOB_HOME}/runit.sh 3 
  sleep 3

  echo "Saving results..."
  if [ ${RAC} -eq 0 ]
  then
    mv ${SLOB_HOME}/awr.txt ${RUN_HOME}/lap0${LAP}.awr.0${NUM_THREADS}threads.${ANF_QUOTA}quota.txt 
    mv ${SLOB_HOME}/mpstat.out ${RUN_HOME}/lap0${LAP}.mpstat.0${NUM_THREADS}threads.${ANF_QUOTA}quota.out
    mv ${SLOB_HOME}/vmstat.out ${RUN_HOME}/lap0${LAP}.vmstat.0${NUM_THREADS}threads.${ANF_QUOTA}quota.out
    mv ${SLOB_HOME}/iostat.out ${RUN_HOME}/lap0${LAP}.nfsiostat.0${NUM_THREADS}threads.${ANF_QUOTA}quota.out
  fi 
  
  if [ ${RAC} -eq 1 ]
  then
    mv ${SLOB_HOME}/awr.txt ${RUN_HOME}/lap0${LAP}.awr.0${NUM_THREADS}threads.rac.txt
    mv ${SLOB_HOME}/awr_rac.txt ${RUN_HOME}/lap0${LAP}.awr_rac.0${NUM_THREADS}threads.rac.txt
    mv ${SLOB_HOME}/mpstat.out ${RUN_HOME}/lap0${LAP}.mpstat.0${NUM_THREADS}threads.rac.out
    mv ${SLOB_HOME}/vmstat.out ${RUN_HOME}/lap0${LAP}.vmstat.0${NUM_THREADS}threads.rac.out
    mv ${SLOB_HOME}/iostat.out ${RUN_HOME}/lap0${LAP}.nfsiostat.0${NUM_THREADS}threads.rac.out
  fi

  echo "Taking a 120 seconds nap before next lap..."
  sleep 120
  if [ ${NUM_THREADS} -eq 1 ]
  then
    NUM_THREADS=$(( NUM_THREADS-1 + INC_THREAD_BY ))
  else
    NUM_THREADS=$(( NUM_THREADS + INC_THREAD_BY ))
  fi

  LAP=$(( LAP + 1 ))
done
