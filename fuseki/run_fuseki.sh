#!/bin/bash

#TODO
# Add --host option: e.g. --host=127.0.0.1 then Fuseki only listens to localhost
Add Fuseki base optionn ...

set -e
set -u
set -o pipefail

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--container)
      CONTAINER="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--fuseki-base)
      RUN_FUSEKI_BASE="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--fuseki-db)
      RUN_FUSEKI_DB="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Fuseki environment variables and default settings
# https://jena.apache.org/documentation/fuseki2/fuseki-layout.html
# FUSEKI_HOME 	Current directory
#	FUSEKI_BASE 	${FUSEKI_HOME}/run/

echo "FUSEKI_BASE   = ${RUN_FUSEKI_BASE}"
echo "FUSEKI_DB = ${RUN_FUSEKI_DB}"

echo "Start container:"
apptainer instance start \
    --bind ${RUN_FUSEKI_BASE}:/etc/fuseki \
    --bind ${RUN_FUSEKI_DB}:/etc/fuseki_db \
    $CONTAINER fuseki