import { ContainerGroup, ContainerInstanceManagementClient } from "@azure/arm-containerinstance";
import { AzureFunction, Context } from "@azure/functions"
import { QueueServiceClient } from "@azure/storage-queue";
import { ClientSecretCredential } from "@azure/identity";

interface RequestMessage {
    op: string,
    account: string,
    container: string,
    file: string
}

async function isContainerGroupRunning(context: Context, containerClient: ContainerInstanceManagementClient) {
    let result : ContainerGroup;
    try {
        result = await containerClient.containerGroups.get(
            process.env["MAPGEN_RESOURCE_GROUP"],
            process.env["MAPGEN_CONTAINER_NAME"]
        )
    } catch (error) {
        context.log.error("Failed to check container group status: " + error);
        return;
    }

    for (const container of result.containers) {
        if (container.instanceView?.currentState?.state != "Terminated") {
            context.log(`Container ${container.name} is active`)
            return true;
        }
    }
    context.log("No containers running")
    return false;
}

async function deployContainerGroup(containerClient: ContainerInstanceManagementClient, worldDataFile: string) {
    await containerClient.containerGroups.beginCreateOrUpdate(process.env["MAPGEN_RESOURCE_GROUP"], process.env["MAPGEN_CONTAINER_NAME"], {
        osType: "linux",
        location: "australiaeast",
        containers: [
            {
                image: process.env["MAPGEN_IMAGE_NAME"],
                name: process.env["MAPGEN_CONTAINER_NAME"],
                resources: {
                    requests: {
                        cpu: 1,
                        memoryInGB: 4
                    },
                },
                environmentVariables: [
                    {
                        name: "SAS_TOKEN",
                        secureValue: process.env["MAPGEN_SAS_TOKEN"],
                    },
                    {
                        name: "WORLD_DATA_FILE",
                        value: worldDataFile
                    }
                ]
            }
        ],
        restartPolicy: "Never",
        imageRegistryCredentials: [
            {
                server: process.env["MAPGEN_REGISTRY_LOGIN_SERVER"],
                username: process.env["MAPGEN_REGISTRY_LOGIN_USERNAME"],
                password: process.env["MAPGEN_REGISTRY_LOGIN_PASSWORD"]
            }
        ]
    })
}


const queueTrigger: AzureFunction = async function (context: Context, myQueueItem: RequestMessage): Promise<void> {

    context.log("Responding to queue trigger:" + myQueueItem);

    try {

    
        const credential = new ClientSecretCredential(process.env["MAPGEN_TENANT_ID"], process.env["MAPGEN_CLIENT_ID"], process.env["MAPGEN_CLIENT_SECRET"])

        const containerClient = new ContainerInstanceManagementClient(credential, process.env["MAPGEN_SUBSCRIPTION_ID"]);
        const queueServiceClient = QueueServiceClient.fromConnectionString(process.env["MAPGEN_QUEUE_CONNECTION_STRING"]);
        const queueClient = queueServiceClient.getQueueClient(process.env["MAPGEN_QUEUE_NAME"])

        if (!myQueueItem.file) {
            context.log.error("Error receiving queue request: file not provided")
            return;
        }

        if (await isContainerGroupRunning(context, containerClient)) {
            const retryDelay = parseFloat(process.env['MAPGEN_RETRY_DELAY'])
            context.log('Received valid map generation request, but the map generator was already running. Re-queueing the request to run in ' + retryDelay + ' seconds.');
            await queueClient.sendMessage(JSON.stringify(myQueueItem), { visibilityTimeout: retryDelay });
            return;
        }

        context.log(`Deploying map generator for ${myQueueItem.file}`);

        await deployContainerGroup(containerClient, myQueueItem.file);

    } catch (error) {
        context.log.error("Error handling message: " + error)
    }
};

export default queueTrigger;
