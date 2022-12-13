#!/bin/bash

# Retrieves a job from the queue, fetches the cache if available, generates the
# map, and uploads it and the cache.

# Environment variables used:

# SAS_TOKEN: A SAS token that has full access to STORAGE_ACCOUNT.
# STORAGE_ACCOUNT: The name of an Azure Storage Account.
# STORAGE_CONTAINER: The name of the container in STORAGE_ACCOUNT that contains archived world data.
# STORAGE_QUEUE: The name of the queue in STORAGE_ACCOUNT that contains job information.
# DESTINATION_CONTAINER: The name of the container in STORAGE_ACCOUNT that the map should be uploded to.
# WORLD_PATH: The path inside the archived world data to the folder containing the 'db' folder.

set -e

echo "Fetching job info..."

# Fetch the first item from the queue

curl "https://$STORAGE_ACCOUNT.queue.core.windows.net/$STORAGE_QUEUE/messages?numofmessages=1&visibilitytimeout=10&$SAS_TOKEN" -o message.xml

MESSAGE_ID="$(xmllint --xpath "//QueueMessagesList/QueueMessage/MessageId/text()" message.xml)"
MESSAGE_POP_RECEIPT="$(xmllint --xpath "//QueueMessagesList/QueueMessage/PopReceipt/text()" message.xml)"
WORLD_DATA_FILE="$(xmllint --xpath "//QueueMessagesList/QueueMessage/MessageText/text()" message.xml | jq -r .file)"

WORLD_DATA_URL="https://$STORAGE_ACCOUNT.blob.core.windows.net/$STORAGE_CONTAINER/$WORLD_DATA_FILE"

# Download the world file as a zip from WORLD_SOURCE_URL
echo "Downloading world from $WORLD_DATA_URL..."

curl $WORLD_DATA_URL -o world.zip

echo "Extracting world file..."
# Extract the downloaded zip file
unzip -o -d world world.zip

echo "Checking for existing cache..."

CACHE_URL="https://$STORAGE_ACCOUNT.blob.core.windows.net/$STORAGE_CONTAINER/chunks.sqlite?$SAS_TOKEN"

curl -f -LI $CACHE_URL

if [ $? == 0 ];
then
    echo "Cache found. Downloading..."
    mkdir -p out
    curl $CACHE_URL -o out/chunks.sqlite

    echo "Restored cache."

    echo "Restoring cached images..."
    mkdir -p out/map
    ./azcopy sync "https://$STORAGE_ACCOUNT.blob.core.windows.net/$DESTINATION_CONTAINER?$SAS_TOKEN" out/map --delete-destination=true

else
    echo "No cache found. Will re-generate map from scratch."
fi

# Run PapyrusCS to generate the data, using the cache
echo "Generating maps..."
PAPYRUS=papyrus-out/PapyrusCs
$PAPYRUS -o out -w "world/$WORLD_PATH" --htmlfile=index.html -d 0 -f jpg -q 70
$PAPYRUS -o out -w "world/$WORLD_PATH" --htmlfile=index.html -d 1 -f jpg -q 70

# Sync the generated map to DESTINATION_URL
echo "Uploading map..."
./azcopy sync out/map "https://$STORAGE_ACCOUNT.blob.core.windows.net/$DESTINATION_CONTAINER?$SAS_TOKEN" --delete-destination=true

echo "Saving cache..."

./azcopy cp out/chunks.sqlite "https://$STORAGE_ACCOUNT.blob.core.windows.net/$STORAGE_CONTAINER/chunks.sqlite?$SAS_TOKEN"


echo "Removing job from queue..."
curl -X DELETE "https://$STORAGE_ACCOUNT.queue.core.windows.net/$STORAGE_QUEUE/messages/$MESSAGE_ID?popreceipt=$MESSAGE_POP_RECEIPT&$SAS_TOKEN"
rm message.xml

echo "Done!"