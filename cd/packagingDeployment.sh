#!/bin/bash

# Script for packaging branch creation

# Instructions:

#   It uses the CIRCLE_BRANCH environment variable as first parameter, passed via the CircleCI job config, as value to determine 
#   for which package a new version should be created and which packages should only be deployed. 

#   It also uses the CI environment
#   variable as safeguard for making sure that the script runs in the CI environment.

# - For a manual run from a developer workstation pass the name of the the package alias as parameter 
#   (instead of the CIRCLE_BRANCH environment variable).

#   Note: When you create a Package, also create an extra version before running this script. 

#   To create subsequent versions & install from a developer workstation assuming alias for his/her Scratch org is MyScratchOrg, run
#   scripts/packagingDeployment.sh packaging MyScratchOrg

#   To install latest version from a developer workstation only (already defined in script below) to the scratch org
#   scripts/packagingDeployment.sh install MyScratchOrg

#   package people create package tag, version & install
#   scripts/packagingDeployment.sh packaging MyScratchOrg

#   Prod (promote version)
#   ??

#   CD branches install (QA, UAT, Prod)
#   scripts/packagingDeployment.sh

# Package specific variables
BUILD_NAME="ECFMG.ES-Base-Objects - CI"
PACKAGE_NAME="EzSpaceBaseObjects"
PACKAGE_VERSION="EzSpaceBaseObjects@0.1.0-1"

# Default values
BRANCH=$1
SFDX_CLI_EXEC=sfdx
TARGET_ORG=''
PROJECT_HOME="$BUILD_NAME/package"

if [ "$#" -eq 0 ]; then
  echo "No parameter provided, this will be full package installation to authenticated CD Org"
  echo "Current directory: ${PWD##*/}"
  # Change directory in Deployment pipeline
  cd "$PROJECT_HOME"
  echo "Current directory changed to: ${PWD##*/}"
  TARGET_ORG="-u CDOrg"
fi

# Used by packaging people for their own installation
if [ "$#" -eq 2 ]; then
  TARGET_ORG="-u $2"
  echo "Using specific org $2"
fi

# doubtfull
# Defining Salesforce CLI exec, depending if it's CI or local dev machine
if [ $CI ]; then
  echo "Script is running on CI"
  SFDX_CLI_EXEC=node_modules/sfdx-cli/bin/run
  TARGET_ORG="-u ciorg"
fi

# Reading the to be installed package version based on the alias@version key from sfdx-project.json
PACKAGE_VERSION="$(cat sfdx-project.json | jq --arg VERSION "$PACKAGE_VERSION" '.packageAliases | .[$VERSION]' | tr -d '"')"

# We're creating a new version
if [ $BRANCH = "packaging" ]; then
  echo "Creating new package version for es-base-objects"
  PACKAGE_VERSION="$($SFDX_CLI_EXEC force:package:version:create -p $PACKAGE_NAME -x -w 10 --json | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
  sleep 300 # We've to wait for package replication.
fi

# Installation in dependency order
echo "Package installation es-base-objects"
$SFDX_CLI_EXEC force:package:install --package $PACKAGE_VERSION -w 10 $TARGET_ORG

#Deleting the Data from records (TODO: fails when record is in use)
sfdx force:apex:execute -f scripts/my-apex-test.txt

#Add the records back
sfdx force:data:tree:import --plan ./data/Plan1.json
sfdx force:data:tree:import --plan ./data/Plan2.json

echo "Done"