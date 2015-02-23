#!/bin/sh
set -e

cleanup() {
    vagrant destroy -f
}

trap cleanup EXIT

PACKAGE="$1"

if [ -z "${PACKAGE}" ]
then
    echo "E: Missing package name."
    exit 1
fi

echo "I: Building package ${PACKAGE}..."
make package PACKAGE=${PACKAGE}
