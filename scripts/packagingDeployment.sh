#!/bin/bash

# Script for packaging branch creation

# Instructions:
#
# - It uses the CIRCLE_BRANCH environment variable as first parameter, passed via the
#   CircleCI job config, as value to determine for which package a new version should
#   be created and which packages should only be deployed. It also uses the CI environment
#   variable as safeguard for making sure that the script runs in the CI environment.
# - For a manual run from a developer workstation pass the name of the the package alias
#   as parameter (instead of the CIRCLE_BRANCH environment variable).

#   When you create a Package, also create an extra version before running this script
#   To create subsequent versions on your local
#   scripts/packagingDeployment.sh es-base-objects MyTP
#   scripts/packagingDeployment.sh es-base-code MyTP
#   scripts/packagingDeployment.sh es-base-styles MyTP
#   scripts/packagingDeployment.sh es-space-mgmt MyTP

#   To install all version on your local
#   TODO:

# Default values
BRANCH=$1
SFDX_CLI_EXEC=sfdx
TARGET_ORG=''
PROJECT_HOME="SalesforceEasySpaces - CI/package"
PACKAGE_VERSION_BASE_OBJECTS="ESBaseObjects@0.1.0-1"
PACKAGE_VERSION_BASE_CODE="ESBaseCode@0.1.0-1"
PACKAGE_VERSION_BASE_STYLES="ESBaseStyles@0.1.0-1"
PACKAGE_VERSION_SPACE_MGMT="ESSpaceManagement@0.1.0-1"

if [ "$#" -eq 0 ]; then
  echo "No parameter provided, this will be full package installation"
  echo "Current directory: ${PWD##*/}"
  # Change directory in Deployment pipeline
  cd "$PROJECT_HOME"
  echo "Current directory changed to: ${PWD##*/}"
  TARGET_ORG="-u CDOrg"
fi

if [ "$#" -eq 2 ]; then
  TARGET_ORG="-u $2"
  echo "Using specific org $2"
fi

# Defining Salesforce CLI exec, depending if it's CI or local dev machine
if [ $CI ]; then
  echo "Script is running on CI"
  SFDX_CLI_EXEC=node_modules/sfdx-cli/bin/run
  TARGET_ORG="-u ciorg"
fi

# Reading the to be installed package version based on the alias@version key from sfdx-project.json
PACKAGE_VERSION_BASE_OBJECTS="$(cat sfdx-project.json | jq --arg VERSION "$PACKAGE_VERSION_BASE_OBJECTS" '.packageAliases | .[$VERSION]' | tr -d '"')"
PACKAGE_VERSION_BASE_CODE="$(cat sfdx-project.json | jq --arg VERSION "$PACKAGE_VERSION_BASE_CODE" '.packageAliases | .[$VERSION]' | tr -d '"')"
PACKAGE_VERSION_BASE_STYLES="$(cat sfdx-project.json | jq --arg VERSION "$PACKAGE_VERSION_BASE_STYLES" '.packageAliases | .[$VERSION]' | tr -d '"')"
PACKAGE_VERSION_SPACE_MGMT="$(cat sfdx-project.json | jq --arg VERSION "$PACKAGE_VERSION_SPACE_MGMT" '.packageAliases | .[$VERSION]' | tr -d '"')"

# We're in a packaging/* branch, so we need to create a new version
if [ "$BRANCH" = *"es-base-objects"* ]; then
  echo "Creating new package version for es-base-objects"
  PACKAGE_VERSION_BASE_OBJECTS="$($SFDX_CLI_EXEC force:package:version:create -p ESBaseObjects -x -w 10 --json | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
  sleep 300 # We've to wait for package replication.
fi
if [ "$BRANCH" = *"es-base-code"* ]; then
  echo "Creating new package version for es-base-code"
  PACKAGE_VERSION_BASE_CODE="$($SFDX_CLI_EXEC force:package:version:create -p ESBaseCode -x -w 10 --json | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
  sleep 300 # We've to wait for package replication.
fi
if [ "$BRANCH" = *"es-base-styles"* ]; then
  echo "Creating new package version for es-base-styles"
  PACKAGE_VERSION_BASE_STYLES="$($SFDX_CLI_EXEC force:package:version:create -p ESBaseStyles -x -w 10 --json | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
  sleep 300 # We've to wait for package replication.
fi
if [ "$BRANCH" = *"es-space-mgmt"* ]; then
  echo "Creating new package version for es-space-mgmt"
  PACKAGE_VERSION_SPACE_MGMT="$($SFDX_CLI_EXEC force:package:version:create -p ESSpaceManagement -x -w 10 --json | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
  sleep 300 # We've to wait for package replication.
fi

# Installation in dependency order
echo "Package installation es-base-objects"
$SFDX_CLI_EXEC force:package:install --package $PACKAGE_VERSION_BASE_OBJECTS -w 10 $TARGET_ORG
echo "Package installation es-base-code"
$SFDX_CLI_EXEC force:package:install --package $PACKAGE_VERSION_BASE_CODE -w 10 $TARGET_ORG
echo "Package installation es-base-styles"
$SFDX_CLI_EXEC force:package:install --package $PACKAGE_VERSION_BASE_STYLES -w 10 $TARGET_ORG
echo "Package installation es-space-mgmt"
$SFDX_CLI_EXEC force:package:install --package $PACKAGE_VERSION_SPACE_MGMT -w 10 $TARGET_ORG

#Deleting the Data from records
sfdx force:apex:execute -f scripts/my-apex-test.txt
#Add the records back
sfdx force:data:tree:import --plan ./data/Plan1.json
sfdx force:data:tree:import --plan ./data/Plan2.json
echo "Done"