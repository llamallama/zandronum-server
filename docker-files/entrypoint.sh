#!/usr/bin/env bash
set -exu

# "coop", "deathmatch", or "invasion"
mode="${1:-}"

if [[ -z "$mode" ]]
then
  echo "mode parameter is required"
  exit 1
fi

configsFolder='configs'     # Contains the folder the server configs live in
globalConfigFolder='global' # Contains global configs
currentServerFile='current' # The file containing the name of the server folder
paramsFile='params'         # The file that contains the zandronum server params

# Get the current server folder from currentServerFile
export CURRENT_SERVER="$(cat "${configsFolder}/${mode}/${currentServerFile}")"

# Create the full path to the params file
paramsFilePath="${configsFolder}/${mode}/${CURRENT_SERVER}/${paramsFile}"

# Replaces ${CURRENT_SERVER} in the params file
# with the name of the current server folder
envsubst < "${paramsFilePath}.template" \
         > "${paramsFilePath}"

# Source the paramaters array from the params file
source "$paramsFilePath"

# Sets passwords in the global config from env vars
envsubst < "${configsFolder}/${globalConfigFolder}/global.cfg.template" \
         > "${configsFolder}/${globalConfigFolder}/global.cfg"

# Do not allow container to be started as non-root user
if (( "$(id -u)" != 0 )); then
    echo "You must run the container as root. To specify a custom user,"
    echo "use the ZANDRONUM_UID and ZANDRONUM_GID environment variables"
    exit 1
fi

 # Create the group for the server process
[[ -n "$ZANDRONUM_GID" ]] && GID_OPTION="--gid $ZANDRONUM_GID"
groupadd zandronum --force ${GID_OPTION-}

# Create the user for the server process
[[ -n "$ZANDRONUM_UID" ]] && UID_OPTION="--uid $ZANDRONUM_UID"
useradd doomguy --create-home ${UID_OPTION-} \
    --shell /sbin/nologin \
    --group zandronum \
    || true # Do not fail if user already exists

# Start the zandronum-server process with local user & group
cd "$INSTALL_DIR" || false
echo gosu doomguy:zandronum zandronum-server -host "${params[@]}"
gosu doomguy:zandronum zandronum-server -host "${params[@]}"
