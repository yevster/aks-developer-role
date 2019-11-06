# The AKS Developer Role

[ACR tasks](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-quick-task#build-in-azure-with-acr-tasks) are a wonderful feature of the Azure Container Registry. Just by typing `az acr build`, you can upload your entire directory to ACR and build the docker image on Azure. It's great for when you don't have permission (or inclination) to run Docker on your own machine.

The only problem: there is no built-in Azure role that allows you to use ACR tasks without also allowing other modifications. That's where the "AKS Developer Role" comes in.

## The role

To put it simply, the AKS Developer Role allows a user or service principal to push and pull images from ACR, run and cancel ACR tasks, and obtain non-administrative AKS credentials (in order to use `kubectl` to test your work).

## Setting up the role

You'll need to edit the file `aksdeveloper.json` to replace the string `${RESOURCE_GROUP}` with the identifier of the scope (typically, a resource group) to which the role shall apply.

From a bash shell, you can follow the steps below. You'll need to use Azure CLI (available via [Azure CloudShell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview)).

```bash
RESOURCE_GROUP="myContainerRG"
RESOURCE_GROUP_ID=$(az group show -g $RESOURCE_GROUP --query id -o tsv)
az role definition create --role-definition "$(cat aksdeveloper.json | sed 's:${RESOURCE_GROUP}:'${RESOURCE_GROUP_ID}':g')"

```

You can then assign the role to a user or a service principal using [`az role assignment create`](https://docs.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create) in Azure CLI or via Azure Portal or PowerShell.

## The test

The files in the `test` directory serve as a semi-automated smoke test of the role. `test.sh` creates a resource group containing ACR and AKS instances, creates a service principal with the AKS Developer role, and then logs in as that service principal and performs an image build and an AKS deployment. You may find this file helpful as an example for how you might automate the creation of your development/dev testing environment.
