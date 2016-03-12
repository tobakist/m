#!/bin/bash

# m - wrapper for mysql cli client using login-path
#
# m -i instancename [-v] [-l] [-w] [-d database] [-c charset]
#
# -i    login-path name (--login-path=..)
#
# -v    verbose (--verbose)
# -l    log (--tee)
# -w    warnings (--show-warnings)
# -d    database
# -c    character set (--default-character-set)

# This is used if mysql is installed in
# /opt/mysql/$MYSQL_DIST.x i.e.
# /opt/mysql/5.7.11
# .m.cnf must contain MYSQL_DIST="x.x"
# and CLIENT_INFO="yes" (or no)
# It will override MYSQL_DIST set here.
if [ -f ${HOME}/bin/.m.cnf ]; then
  . ${HOME}/bin/.m.cnf
else
  MYSQL_DIST="5.7"
  CLIENT_INFO="yes"
fi

# Date on logfile names
DATEFORMAT=`date +%Y-%m-%d_%H:%M:%S`
# Directory for logfiles
LOGDIR="${HOME}/.mylog"
# Number of days to keep old logfiles
KEEPLOGS=30
# Default is to not use --verbose
VERBOSE=0
# Default is to not use --tee
LOG=0
# Default is to not use --show-warnings
WARNINGS=0
# Change if utf8 is not default
# (friends don't let friends use latin1)
DEFAULT_CHARSET="utf8"
# No default database
DATABASE="_"

i_SET=0
EXTRA=0
USAGE="Usage: `basename ${0}` -i login-path [-v] [-l] [-w] [-d databasename] [-c charset (default: ${DEFAULT_CHARSET})]"

if [ $# -lt 2 ]; then
  echo "${USAGE}"
  exit 1
fi

while getopts ":i:c:d:wvl" opt; do
  case $opt in
    i  ) INSTANCE=${OPTARG} && i_SET=1 ;;
    v  ) VERBOSE=1                     ;;
    l  ) LOG=1                         ;;
    c  ) _CHARSET=${OPTARG}            ;;
    d  ) DATABASE=${OPTARG}            ;;
    w  ) WARNINGS=1                    ;;
    \? ) echo "${USAGE}" && exit 1     ;;
    :  ) echo "${USAGE}" && exit 1     ;;
  esac
done

if [ ${i_SET} -eq 0 ]; then
  echo "ERROR: -i must be specified."
  echo "${USAGE}"
  exit 1
fi

# If we do have /opt/mysql/x.x.x which contains bin/ then we use that
# We (hopefully) find the latest.
if find /opt/mysql -maxdepth 1 -type d -name "${MYSQL_DIST}.*" >/dev/null 2>&1 ; then
  MYSQL_VERSION="`find /opt/mysql -maxdepth 1 -type d -name "${MYSQL_DIST}.*" -print | sort -V | tail -1`"
  PATH=${MYSQL_VERSION}/bin:$PATH
else
  MYSQL_VERSION="Unknown version"
fi

# If /opt/mysql/x.x.x does not exist, let's hope you have mysql
# and mysql_config_editor installed elsewhere in your $PATH

which mysql >/dev/null 2>&1

if [ ${?} -ne 0 ]; then
  echo "ERROR: mysql client not in path."
  echo "${USAGE}"
  exit 1
fi

which mysql_config_editor >/dev/null 2>&1

if [ ${?} -ne 0 ]; then
  echo "ERROR: mysql_config_editor not in path."
  echo "${USAGE}"
  exit 1
else
  MCE="`which mysql_config_editor`"
fi

CHARSET=${_CHARSET:-$DEFAULT_CHARSET}

mysql_config_editor print --login-path=${INSTANCE} | grep -q "\[${INSTANCE}\]"

if [ ${?} -ne 0 ]; then
  echo "ERROR: login-path ${INSTANCE} does not exist."
  echo "INFO: Create login-path with, for example,  '${MCE} set --login-path=name --socket=/path/to/sock.sock --user=username'"
  echo "${USAGE}"
  exit 1
fi

if [ ${LOG} -eq 1 ]; then
  if [ ! -d ${LOGDIR} ]; then
    mkdir ${LOGDIR}
  fi

  find ${LOGDIR} -type f -name "*.log" -mtime +${KEEPLOGS} -exec rm {} \;
fi

CLIENTCMD="mysql --login-path=${INSTANCE} --default-character-set=${CHARSET}"

if [ ${VERBOSE} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --verbose"
fi

if [ ${LOG} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --tee=${LOGDIR}/${INSTANCE}-${DATEFORMAT}.log"
fi

if [ ${WARNINGS} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --show-warnings"
fi

if [ ${DATABASE} != "_" ]; then
  CLIENTCMD="${CLIENTCMD} ${DATABASE}"
fi

if [ ${CLIENT_INFO} == "yes" ]; then
  if [ ${DATABASE} == "_" ]; then
    DBNAME="none"
  else
    DBNAME="${DATABASE}"
  fi
  echo "-- MySQL Version: ${MYSQL_VERSION}, client: `which mysql`, database: ${DBNAME}"
fi

${CLIENTCMD}
