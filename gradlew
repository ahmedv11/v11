#!/usr/bin/env sh

#
# Copyright 2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This script is modelled on the Maven wrapper script created by
# Jason van Zyl.
#

#
# Resolve the location of the Gradle Wrapper distribution by finding the
# gradle-wrapper.properties file somewhere in the directory tree.
#

# Base name of the gradle wrapper files
WRAPPER_BASE_NAME=gradlew

# Directory to store the gradle distributions
GRADLE_USER_HOME_DIR_NAME=".gradle"
# Directory to store the gradle wrapper distributions
WRAPPER_DIR_NAME="wrapper"
# Directory to store the gradle wrapper distributions
WRAPPER_DISTRIBUTION_DIR_NAME="dists"

# The properties file is used to determine the version of Gradle to use
WRAPPER_PROPERTIES_FILE="gradle/${WRAPPER_DIR_NAME}/${WRAPPER_BASE_NAME}.properties"

# The jar file is the code run by the wrapper script
WRAPPER_JAR_FILE="gradle/${WRAPPER_DIR_NAME}/${WRAPPER_BASE_NAME}.jar"

# Set script variables
set_script_variables() {
    # Determine the location of this script
    # Need to use PWD because on some systems $0 is relative to the cwd if the script is invoked
    # with ./gradlew
    # Need to use dirname because on some systems $0 contains the script name
    # Need to use `cd ..` because on some systems dirname does not handle ..
    # Need to use `pwd` because on some systems `cd` does not print the resulting directory
    # Need to use `readlink` because on some systems $0 is a symlink
    SCRIPT_DIR=$(dirname "$(readlink -f "$0" || realpath "$0")")

    # Determine the location of the gradle-wrapper.properties file
    # Need to use `cd` because on some systems dirname does not handle ..
    # Need to use `pwd` because on some systems `cd` does not print the resulting directory
    PROPERTIES_FILE="$(cd "${SCRIPT_DIR}" && pwd -P)/${WRAPPER_PROPERTIES_FILE}"

    # Determine the location of the gradle-wrapper.jar file
    # Need to use `cd` because on some systems dirname does not handle ..
    # Need to use `pwd` because on some systems `cd` does not print the resulting directory
    JAR_FILE="$(cd "${SCRIPT_DIR}" && pwd -P)/${WRAPPER_JAR_FILE}"
}

# Parse the wrapper properties file and set the distribution URL
parse_properties() {
    if [ ! -f "${PROPERTIES_FILE}" ]; then
        echo "ERROR: ${WRAPPER_PROPERTIES_FILE} not found."
        echo "Please run ./gradlew wrapper --gradle-version <version> to generate the wrapper files."
        exit 1
    fi
    # Read the distributionUrl property from the properties file
    # Use grep and sed to extract the value
    DISTRIBUTION_URL=$(grep -E ".*distributionUrl.*" "${PROPERTIES_FILE}" | sed -e "s/\\\\/\\/g" -e "s/distributionUrl=//" -e "s/\\:/:/g")
    if [ -z "${DISTRIBUTION_URL}" ]; then
        echo "ERROR: distributionUrl property not found in ${PROPERTIES_FILE}."
        exit 1
    fi
}

# Determine the location of the Gradle distribution
# This is determined by the distributionUrl property in the properties file
# The distribution is stored in the user's gradle home directory
# The location is based on a hash of the distributionUrl
# This ensures that different distributions are stored in different directories
# If the distribution is not found, it is downloaded
# If the distribution is found, it is used
# If the distribution cannot be downloaded, an error is reported
# If the distribution cannot be used, an error is reported
determine_gradle_distribution() {
    # Determine the gradle user home directory
    if [ -z "${GRADLE_USER_HOME}" ]; then
        GRADLE_USER_HOME="${HOME}/${GRADLE_USER_HOME_DIR_NAME}"
    fi

    # Determine the wrapper distribution directory
    WRAPPER_DISTRIBUTION_DIR="${GRADLE_USER_HOME}/${WRAPPER_DIR_NAME}/${WRAPPER_DISTRIBUTION_DIR_NAME}"

    # Determine the distribution base name
    DISTRIBUTION_BASE_NAME=$(basename "${DISTRIBUTION_URL}" | sed -e "s/-bin.zip$//" -e "s/-all.zip$//")

    # Determine the distribution directory name
    # This is based on a hash of the distributionUrl
    # Use md5sum or shasum if available
    if command -v md5sum >/dev/null 2>&1; then
        DISTRIBUTION_SHA=$(echo "${DISTRIBUTION_URL}" | md5sum | cut -d\  -f1)
    elif command -v shasum >/dev/null 2>&1; then
        DISTRIBUTION_SHA=$(echo "${DISTRIBUTION_URL}" | shasum | cut -d\  -f1)
    else
        # Fallback to using the base name if no hashing command is available
        DISTRIBUTION_SHA="${DISTRIBUTION_BASE_NAME}"
    fi
    DISTRIBUTION_DIR="${WRAPPER_DISTRIBUTION_DIR}/${DISTRIBUTION_BASE_NAME}/${DISTRIBUTION_SHA}"

    # Determine the gradle home directory for the distribution
    GRADLE_HOME="${DISTRIBUTION_DIR}/${DISTRIBUTION_BASE_NAME}"
}

# Download the gradle distribution if it is not already present
download_gradle_distribution() {
    if [ -d "${GRADLE_HOME}" ]; then
        # Distribution already exists
        return
    fi

    # Create the distribution directory
    mkdir -p "${DISTRIBUTION_DIR}"
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not create directory ${DISTRIBUTION_DIR}."
        exit 1
    fi

    # Download the distribution
    DISTRIBUTION_ZIP="${DISTRIBUTION_DIR}/${DISTRIBUTION_BASE_NAME}.zip"
    echo "Downloading ${DISTRIBUTION_URL}"
    # Use curl or wget if available
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --output "${DISTRIBUTION_ZIP}" "${DISTRIBUTION_URL}"
    elif command -v wget >/dev/null 2>&1; then
        wget --output-document="${DISTRIBUTION_ZIP}" "${DISTRIBUTION_URL}"
    else
        echo "ERROR: Neither curl nor wget found. Please install one."
        exit 1
    fi
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not download ${DISTRIBUTION_URL}."
        exit 1
    fi

    # Unzip the distribution
    echo "Unzipping ${DISTRIBUTION_ZIP} to ${DISTRIBUTION_DIR}"
    # Use unzip command
    unzip -q -d "${DISTRIBUTION_DIR}" "${DISTRIBUTION_ZIP}"
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not unzip ${DISTRIBUTION_ZIP}."
        exit 1
    fi

    # Delete the zip file
    rm "${DISTRIBUTION_ZIP}"
}

# Run gradle
run_gradle() {
    # Check if the gradle executable exists
    GRADLE_EXE="${GRADLE_HOME}/bin/gradle"
    if [ ! -x "${GRADLE_EXE}" ]; then
        echo "ERROR: Gradle executable not found or not executable: ${GRADLE_EXE}"
        exit 1
    fi

    # Set GRADLE_HOME environment variable
    export GRADLE_HOME

    # Execute gradle
    echo "Running Gradle..."
    exec "${GRADLE_EXE}" "$@"
}

# Main script execution
set_script_variables
parse_properties
determine_gradle_distribution
download_gradle_distribution
run_gradle "$@"

