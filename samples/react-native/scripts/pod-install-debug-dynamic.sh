#!/bin/bash

# Exit on error
set -e

export ENABLE_PROD=0
export ENABLE_NEW_ARCH=1
export USE_FRAMEWORKS=dynamic

thisFilePath=$(dirname "$0")

"${thisFilePath}/pod-install.sh"
