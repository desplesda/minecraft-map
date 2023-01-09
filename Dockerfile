# 1. Build Papyrus, with local modifications.

FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy AS build

COPY scripts/build.sh .
COPY papyruscs.patch .

RUN ./build.sh

# 2. Prepare the container for use.

FROM mcr.microsoft.com/dotnet/runtime:7.0-jammy

COPY --from=build papyrus-out papyrus-out

COPY scripts/run.sh .
COPY scripts/setup.sh .

RUN ./setup.sh

# The name of an Azure Storage Account.
ENV STORAGE_ACCOUNT="gnomeminecraft"

# The name of the container in STORAGE_ACCOUNT that contains archived world data.
ENV STORAGE_CONTAINER="world-data"

# The name of the queue in STORAGE_ACCOUNT that contains job information.
ENV STORAGE_QUEUE="map-updates"

# The name of the container in STORAGE_ACCOUNT that the map should be uploaded to.
ENV DESTINATION_CONTAINER='$web'

# A SAS token that has full access to STORAGE_ACCOUNT.
ENV SAS_TOKEN='<missing>'

# The path inside the archived world data to the folder containing the 'db' folder.
ENV WORLD_PATH="Gnome World"

ENV WORLD_DATA_FILE='<missing>'

CMD [ "./run.sh" ]
