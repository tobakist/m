#!/bin/bash

VERSION="1.2"

# 1.0
# Thomas Johansson 2016-03-07
# * A pretty bad script
#
# 1.1
# Thomas Johansson 2018-02-21
# * Added support for passwords outside of login-path
# * Changed default charset to utf8mb4
#
# 1.2
# Thomas Johansson 2018-02-28
# * Changed tee to be default
# * Added -d databasename
# * Added more info to CLIENT_INFO display
# * Cleaned up USAGE to reflect reality
# * Removed pointless EXTRA-variable
# * Added this changelog
# * Added some helpful comments


# m - wrapper for mysql cli client using login-path
#
# m -i instancename [-v] [-l] [-w] [-n] [-d dbname] [-c charset]
#
# -i	login-path name (--login-path=..)
# -v	verbose (--verbose)
# -l	no log (--tee)
# -n    no password
# -w	warnings (--show-warnings)
# -c	character set (--default-character-set)
# -d    databasename

# This is used if mysql is installed in
# /opt/mysql/$MYSQL_DIST.x i.e.
# /opt/mysql/5.7.11
#
# .m.cnf must contain
#
# MYSQL_DIST="x.x"
# CLIENT_INFO="yes" # or "no"
#
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
# Number of days ish to keep old logfiles
KEEPLOGS=30
# Default is to not use --verbose
VERBOSE=0
# Default is to use --tee
LOG=1
# Default is to not use --show-warnings
WARNINGS=0
# Use password (if 0, password must be stored in login-path)
PASSWORDS=1
# Change if utf8mb4 is not default
# (Remember: friends don't let friends use latin1)
DEFAULT_CHARSET="utf8mb4"
# Default database, default to none (dont name your database "__none" kthnx
DEFAULT_DATABASE="__none"

USAGE="Usage: `basename ${0}` -i login-path [-v] (verbose) [-l] (no tee) [-w] (warnings) [-d dbname] [-n] (no password) [-c charset] (default: ${DEFAULT_CHARSET})"
i_SET=0

if [ $# -lt 2 ]; then
  echo "${USAGE}"
  exit 1
fi

while getopts ":i:c:d:wvln" opt; do
  case $opt in
    i  ) INSTANCE=${OPTARG} && i_SET=1 ;;
    v  ) VERBOSE=1                     ;;
    l  ) LOG=0                         ;;
    c  ) _CHARSET=${OPTARG}            ;;
    w  ) WARNINGS=1                    ;;
    n  ) PASSWORDS=0                   ;;
    d  ) DEFAULT_DATABASE=${OPTARG}    ;;
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
  echo "INFO: Create login-path with for example '${MCE} set --login-path=${INSTANCE} --host=192.168.1.1 --port=3306 --user=username'"
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

# Add verbose
if [ ${VERBOSE} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --verbose"
fi

# Add password authentication
if [ ${PASSWORDS} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} -p"
fi

# Add logfile
if [ ${LOG} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --tee=${LOGDIR}/${INSTANCE}-${DATEFORMAT}.log"
fi

# Show all warnings
if [ ${WARNINGS} -eq 1 ]; then
  CLIENTCMD="${CLIENTCMD} --show-warnings"
fi

# Add databasename, keep as last addition to CLIENTCMD
if [ ${DEFAULT_DATABASE} != "__none" ]; then
  CLIENTCMD="${CLIENTCMD} ${DEFAULT_DATABASE}"
fi

if [ ${CLIENT_INFO} == "yes" ]; then echo "-- MySQL Version: `basename ${MYSQL_VERSION}`, client: `which mysql`"; fi
if [ ${CLIENT_INFO} == "yes" ]; then echo "-- Connecting with: ${CLIENTCMD}"; fi

${CLIENTCMD}

