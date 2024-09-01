#!/bin/bash

#TODO Hard code database location to /etc/fuseki_base ... then bind a host directory to it ...
#TODO Nicer prompts. Autocompletion when asking for the path.
#TODO How to set FUSEKI_BASE for the run_fuseki.sh script?

set -e
set -u
set -o pipefail

setup () {
    if [ ! -d etc_fuseki ]; then
        echo "Creating directory: etc_fuseki"
        mkdir etc_fuseki
    fi

    # Copy configuration templates.
    if [ ! -f "../configuration/fuseki-jetty-https.xml" ]; then
        echo "No default configuration found at: ../configuration/fuseki-jetty-https.xml"
        exit 1
    fi
    cp ../configuration/fuseki-jetty-https.xml etc_fuseki/
    cp ../configuration/config.ttl etc_fuseki/
    cp ../configuration/log4j2.properties etc_fuseki/
    cp ../configuration/shiro.ini etc_fuseki/
    cp ../configuration/web.xml etc_fuseki/

    # Delete existing keystore?
    if [ -f etc_fuseki/fuseki_keystore.p12 ]; then
        read -p "KeyStore already exists. Delete? [y/n]" -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            rm etc_fuseki/fuseki_keystore.p12
        fi
        echo "---------------------------------------------"
    fi
}

create_ss_cert () {
    # Ask for keystore password
    echo "Create self-signed SSL certificate creation"
    echo "Enter keystore password:"
    read -s KEYSTORE_PW

    keytool \
        -genkeypair \
        -alias fuseki_server \
        -validity 3650 \
        -storepass ${KEYSTORE_PW} \
        -keyalg RSA \
        -keysize 2048 \
        -keystore etc_fuseki/fuseki_keystore.p12 \
        -dname "CN=127.0.0.1, OU=Unit, O=Company, L=City, S=State, C=Country" \
        -ext san=ip:127.0.0.1 \
        -v 

    sed -i "s/KEYSTORE_PW/${KEYSTORE_PW}/g" etc_fuseki/fuseki-jetty-https.xml
}

setup_fuseki_base () {
    # Ask for FUSEKI_BASE directory
    echo "Specify FUSEKI_BASE directory:"
    echo "This directory will be bound to the container read/writable. Among other it will contain the database."
    echo ""
    echo "Enter your FUSEKI_BASE directory:"
    read -p "FUSEKI_BASE: " FUSEKI_BASE

    if [ -d ${FUSEKI_BASE} ]; then

        read -e -p "Directory already exists: ${FUSEKI_BASE}. Use it anyway? [y/n]" -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Do not use already existing directory as FUSEKI_BASE: S{FUSEKI_BASE}"
            exit 1
        fi
    else
        echo $FUSEKI_BASE
        mkdir $FUSEKI_BASE
    fi

    echo "Set tdb2:location in etc_fuseki/config.ttl"
    DB2_DIR=${FUSEKI_BASE}/databases/DB2/
    sed -i "s|/etc/fuseki/databases/DB2|${DB2_DIR}|g" etc_fuseki/config.ttl
}

# Setup/Reset configuration
setup

# Create self-signed cert and Java KeyStore
create_ss_cert

# Setup FUSEKI_BASE directory
#setup_fuseki_base