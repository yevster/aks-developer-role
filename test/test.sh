#!/bin/bash

# *** A script for verifying that the AKS Developer role is capable
#     of performing all necessary development tasks. ***

RESOURCE_GROUP='devroletest'
LOCATION=eastus
ACR_NAME="${RESOURCE_GROUP}acr"
AKS_NAME="${RESOURCE_GROUP}aks"
RESOURCE_GROUP_ID=$(az group create -g $RESOURCE_GROUP -l $LOCATION --query id -o tsv)
az acr create -g $RESOURCE_GROUP -n $ACR_NAME --sku Standard
AKS_ID=$(az aks create -g $RESOURCE_GROUP -n $AKS_NAME -c 1 --attach-acr $ACR_NAME --query 'id' -o tsv)

# Create a service principal to do the test and give it the custom role
TEST_SP_NAME="${RESOURCE_GROUP}sp"
az role definition create --role-definition "$(cat ../aksdeveloper.json | sed 's:${RESOURCE_GROUP}:'${RESOURCE_GROUP_ID}':g')"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TEST_SP=$(az ad sp create-for-rbac -n $TEST_SP_NAME --scopes $RESOURCE_GROUP_ID --role 'AKS Developer')

# Generate and run the test script to log in as the service principal, run "az acr build",
# run the built image on AKS, and verify that it starts.
echo "az login --service-principal -u $(echo $TEST_SP | jq '.appId' -r) -p $(echo $TEST_SP | jq '.password' -r) --tenant $(echo $TEST_SP | jq '.tenant' -r)" > runAsSp.sh
echo "az acr build -g '${RESOURCE_GROUP}' -r '${ACR_NAME}' -t ${ACR_NAME}.azurecr.io/testimage:latcdest ." >> runAsSp.sh
echo "export KUBECONFIG=.kube" >> runAsSp.sh
echo "az aks get-credentials -f .kube -g ${RESOURCE_GROUP} -n ${AKS_NAME}" >> runAsSp.sh
echo "kubectl create namespace test" >> runAsSp.sh
echo "kubectl -n test run roletest --image ${ACR_NAME}.azurecr.io/testimage:latest" >> runAsSp.sh
echo 'podName=$(kubectl get pods -n test -o jsonpath="{.items[0].metadata.name}")' >> runAsSp.sh
echo 'sleep 10; output=$(kubectl logs $podName -n test)'  >> runAsSp.sh
echo $'if [ "We\'re off to the races!" == "$output" ]; then echo "Test passed"; else echo "Test failed: ${output}"; fi'  >> runAsSp.sh

bash runAsSp.sh

# CLEANUP. We'll need to log in as the original user.
echo "A browser window will open for interactive login"
az login > /dev/null

az ad sp delete --id $(echo $TEST_SP | jq '.appId' -r)
az group delete -g "${RESOURCE_GROUP}" --no-wait --yes
rm -f runAsSp.sh
rm -f .kube
