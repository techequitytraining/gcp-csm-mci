#!/bin/bash
#
# Copyright 2024 Tech Equity Cloud Services Ltd
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# 
################################################################################
######          Explore Cloud Service Mesh Multi-Cluster Ingress          ######
################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-csm-mci > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-csm-mci
export SCRIPTNAME=gcp-csm-mci.sh
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)')

function join_by { local IFS="$1"; shift; echo "$*"; }

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_1=anthos-mci-1
export GCP_CLUSTER_2=anthos-mci-2
export ASM_VERSION=1.21.4-asm.5
export ASM_INSTALL_SCRIPT_VERSION=1.20
export GCP_REGION_1=europe-west4
export GCP_ZONE_1=europe-west4-b
export GCP_MACHINE_1=e2-standard-4
export GCP_REGION_2=asia-south1
export GCP_ZONE_2=asia-south1-b
export GCP_MACHINE_2=e2-standard-4
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAME=hipster
export GCP_SUBNET_1=10.164.0.0/20
export GCP_SUBNET_2=10.128.0.0/20

# Display menu options
while :
do
clear
cat<<EOF
==============================================================
Menu for Exploring Anthos Multi-Cluster Ingress using ASM 
--------------------------------------------------------------
Please enter number to select your choice:
(0) Switch between Preview, Create and Delete modes
(1) Install tools
(2) Enable APIs
(3) Create Kubernetes clusters
(4) Install Anthos Service Mesh
(5) Deploy microservices 
(6) Configure multi cluster ingress 
(G) Launch user guide
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_1=$GCP_CLUSTER_1
export GCP_CLUSTER_2=$GCP_CLUSTER_2
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
export GCP_REGION_1=$GCP_REGION_1
export GCP_ZONE_1=$GCP_ZONE_1
export GCP_MACHINE_1=$GCP_MACHINE_1
export GCP_REGION_2=$GCP_REGION_2
export GCP_ZONE_2=$GCP_ZONE_2
export GCP_MACHINE_2=$GCP_MACHINE_2
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project 1 is $GCP_PROJECT_1 ***" | pv -qL 100
        echo "*** Google Cloud cluster 1 is $GCP_CLUSTER_1 ***" | pv -qL 100
        echo "*** Google Cloud region 1 is $GCP_REGION_1 ***" | pv -qL 100
        echo "*** Google Cloud zone 1 is $GCP_ZONE_1 ***" | pv -qL 100
        echo "*** Google Cloud machine type 1 is $GCP_MACHINE_1 ***" | pv -qL 100
        echo "*** Google Cloud project 2 is $GCP_PROJECT_2 ***" | pv -qL 100
        echo "*** Google Cloud cluster 2 is $GCP_CLUSTER_2 ***" | pv -qL 100
        echo "*** Google Cloud region 2 is $GCP_REGION_2 ***" | pv -qL 100
        echo "*** Google Cloud zone 2 is $GCP_ZONE_2 ***" | pv -qL 100
        echo "*** Google Cloud machine type 1 is $GCP_MACHINE_2 ***" | pv -qL 100
        echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
        echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_1=$GCP_CLUSTER_1
export GCP_CLUSTER_2=$GCP_CLUSTER_2
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
export GCP_REGION_1=$GCP_REGION_1
export GCP_ZONE_1=$GCP_ZONE_1
export GCP_MACHINE_1=$GCP_MACHINE_1
export GCP_REGION_2=$GCP_REGION_2
export GCP_ZONE_2=$GCP_ZONE_2
export GCP_MACHINE_2=$GCP_MACHINE_2
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project 1 is $GCP_PROJECT_1 ***" | pv -qL 100
                echo "*** Google Cloud cluster 1 is $GCP_CLUSTER_1 ***" | pv -qL 100
                echo "*** Google Cloud region 1 is $GCP_REGION_1 ***" | pv -qL 100
                echo "*** Google Cloud zone 1 is $GCP_ZONE_1 ***" | pv -qL 100
                echo "*** Google Cloud machine type 1 is $GCP_MACHINE_1 ***" | pv -qL 100
                echo "*** Google Cloud project 2 is $GCP_PROJECT_2 ***" | pv -qL 100
                echo "*** Google Cloud region 2 is $GCP_REGION_2 ***" | pv -qL 100
                echo "*** Google Cloud cluster 2 is $GCP_CLUSTER_2 ***" | pv -qL 100
                echo "*** Google Cloud zone 2 is $GCP_ZONE_2 ***" | pv -qL 100
                echo "*** Google Cloud machine type 2 is $GCP_MACHINE_2 ***" | pv -qL 100
                echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
                echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_\${ASM_INSTALL_SCRIPT_VERSION} > \$PROJDIR/asmcli # to download script" | pv -qL 100
    echo
    echo "$ curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > \$PROJDIR/kpt && chmod 755 \$PROJDIR/kpt # to install required apt version" | pv -qL 100
    echo
    echo "$ \$PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-\${ASM_INSTALL_SCRIPT_VERSION} \$PROJDIR/asm # to download the asm package iap-operator.yaml" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    rm -rf asm* istio* .asm*
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli # to download script" | pv -qL 100
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli
    echo
    echo "$ chmod +x $PROJDIR/asmcli # to make the script executable" | pv -qL 100
    chmod +x $PROJDIR/asmcli
    echo
    echo "$ curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > $PROJDIR/kpt && chmod 755 $PROJDIR/kpt # to install required apt version" | pv -qL 100
    curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > $PROJDIR/kpt && chmod 755 $PROJDIR/kpt
    echo
    echo "$ $PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-${ASM_INSTALL_SCRIPT_VERSION} $PROJDIR/asm # to download the asm package iap-operator.yaml" | pv -qL 100
    $PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-${ASM_INSTALL_SCRIPT_VERSION} $PROJDIR/asm
    export PATH=$PROJDIR/istio-${ASM_VERSION}/bin:$PATH > /dev/null 2>&1 # to set ASM path 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ rm -rf $PROJDIR # to delete directory" | pv -qL 100
    rm -rf $PROJDIR 
else
    export STEP="${STEP},1i"
    echo
    echo "1. Download ASM script" | pv -qL 100
    echo "2. Install required apt version" | pv -qL 100
    echo "3. Download asm package IAP operator" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},2i(${i})"   
        echo
        echo "$ gcloud services enable gkehub.googleapis.com multiclusterservicediscovery.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com multiclusteringress.googleapis.com dns.googleapis.com --project \$PROJECT # to enable APIs" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},2(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        echo
        echo "$ gcloud services enable gkehub.googleapis.com multiclusterservicediscovery.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com multiclusteringress.googleapis.com dns.googleapis.com --project $PROJECT # to enable APIs" | pv -qL 100
        gcloud services enable gkehub.googleapis.com multiclusterservicediscovery.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com multiclusteringress.googleapis.com dns.googleapis.com --project $PROJECT
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},2x(${i})"   
        echo
        echo "*** Nothing to delete ***" | pv -qL 100
    else
        export STEP="${STEP},2i"   
        echo
        echo "1. Enable APIs" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i(${i})"   
    if [ "$i" -eq 1 ]; then
        echo
        echo "$ gcloud beta container clusters create \$CLUSTER_NAME --zone \$CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=\${WORKLOAD_POOL} --labels=mesh_id=\${MESH_ID},location=\$CLUSTER_LOCATION --spot --project \$PROJECT_ID # to create cluster" | pv -qL 100
    else
        echo
        echo "$ gcloud beta container clusters create \$CLUSTER_NAME --zone \$CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=\${WORKLOAD_POOL} --labels=mesh_id=\${MESH_ID},location=\$CLUSTER_LOCATION --spot --project \$PROJECT_ID # to create cluster" | pv -qL 100
    fi
    echo
    echo "$ kubectl config use-context \$CTX # to set context" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$PROJECT_ID --member user:\"\$(gcloud config get-value core/account)\" --role=roles/editor --role=roles/compute.admin --role=roles/container.admin --role=roles/resourcemanager.projectIamAdmin --role=roles/iam.serviceAccountAdmin --role=roles/iam.serviceAccountKeyAdmin --role=roles/gkehub.admin --project \$PROJECT_ID # to ensure user is able to register and connect cluster" | pv -qL 100
    echo
    echo "$ gcloud container hub memberships register \$CLUSTER --project=\$PROJECT_ID --gke-cluster=\$ZONE/\$CLUSTER --enable-workload-identity" | pv -qL 100
    echo
    echo "$ gcloud container hub multi-cluster-services enable --project \$PROJECT_ID # to enable MCS"
    echo
    echo "$ gcloud projects add-iam-policy-binding \${PROJECT_ID} --member \"serviceAccount:\${PROJECT_ID}.svc.id.goog[gke-mcs/gke-mcs-importer]\" --role \"roles/compute.networkViewer\" --project=\${PROJECT_ID} # to grant required IAM permissions for MCS" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\$(gcloud config get-value core/account) # to grant current user cluster admin priviledges" | pv -qL 100
    if [ $i -eq 1 ]; then
        echo
        echo "$ kubectl kustomize \"github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0\" | kubectl apply -f - --context=gke-west-1 # to deploy Gateway resources" | pv -qL 100
        echo
        echo "$ gcloud alpha container hub ingress enable --config-membership=projects/\$PROJECT_ID/locations/\$REGION/memberships/\$CLUSTER --quiet --project \$PROJECT_ID # to enable Multi-cluster Gateway controller and select config cluster" | pv -qL 100
        echo
        echo "gcloud projects add-iam-policy-binding \${PROJECT_ID} --member \"serviceAccount:service-\${PROJECT_ID_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com\" --role \"roles/container.admin\" --project=\${PROJECT_ID} # to grant IAM permissions required by Gateway controller" | pv -qL 100
    fi
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3(${i})"   
    export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
    export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
    export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
    export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
    export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
    export REGION=${!GCP_REGION} > /dev/null 2>&1
    export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
    export ZONE=${!GCP_ZONE} > /dev/null 2>&1
    export GCP_MACHINE=$(echo GCP_MACHINE_$(eval "echo $i")) > /dev/null 2>&1
    export MACHINE=${!GCP_MACHINE} > /dev/null 2>&1
    export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
    export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT} --format="value(projectNumber)")
    export IDNS=${PROJECT}.svc.id.goog # used to enable Workload Identity
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster, required for metrics to get displayed on ASM Dashboard
    export PROJECT_ID=${PROJECT}
    export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
    export CLUSTER_ZONE=${ZONE}
    export CLUSTER_NAME=${CLUSTER}
    export CLUSTER_LOCATION=${ZONE}
    gcloud config set project $PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $ZONE > /dev/null 2>&1
    if [ "$i" -eq 1 ]; then
        echo
        echo "$ gcloud beta container clusters create $CLUSTER_NAME --zone $CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$CLUSTER_LOCATION --spot --project $PROJECT_ID # to create cluster" | pv -qL 100
        gcloud beta container clusters create $CLUSTER_NAME --zone $CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$CLUSTER_LOCATION --spot --project $PROJECT_ID
    else
        echo
        echo "$ gcloud beta container clusters create $CLUSTER_NAME --zone $CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$CLUSTER_LOCATION --spot --project $PROJECT_ID # to create cluster" | pv -qL 100
        gcloud beta container clusters create $CLUSTER_NAME --zone $CLUSTER_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$CLUSTER_LOCATION --spot --project $PROJECT_ID
    fi
    echo
    echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
    kubectl config use-context $CTX 
    echo
    echo "$ gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID # to retrieve the credentials for cluster" | pv -qL 100
    gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID
    echo
    echo "$ gcloud projects add-iam-policy-binding $PROJECT --member user:\"\$(gcloud config get-value core/account)\" --role=roles/editor --role=roles/compute.admin --role=roles/container.admin --role=roles/resourcemanager.projectIamAdmin --role=roles/iam.serviceAccountAdmin --role=roles/iam.serviceAccountKeyAdmin --role=roles/gkehub.admin --project $PROJECT_ID # to ensure user is able to register and connect cluster" | pv -qL 100
    gcloud projects add-iam-policy-binding $PROJECT --member user:"$(gcloud config get-value core/account)" --role=roles/editor --role=roles/compute.admin --role=roles/container.admin --role=roles/resourcemanager.projectIamAdmin --role=roles/iam.serviceAccountAdmin --role=roles/iam.serviceAccountKeyAdmin --role=roles/gkehub.admin --project $PROJECT_ID
    echo
    gcloud container fleet memberships delete $CLUSTER --quiet --project $PROJECT_ID > /dev/null 2>&1 
    echo "$ gcloud container hub memberships register $CLUSTER --project=$PROJECT --gke-cluster=$ZONE/$CLUSTER --enable-workload-identity --project $PROJECT_ID" | pv -qL 100
    gcloud container hub memberships register $CLUSTER --project=$PROJECT --gke-cluster=$ZONE/$CLUSTER --enable-workload-identity --project $PROJECT_ID
    echo
    echo "$ gcloud container hub multi-cluster-services enable --project $PROJECT # to enable MCS"
    gcloud container hub multi-cluster-services enable --project $PROJECT
    echo
    echo "$ gcloud projects add-iam-policy-binding ${PROJECT} --member \"serviceAccount:${PROJECT}.svc.id.goog[gke-mcs/gke-mcs-importer]\" --role \"roles/compute.networkViewer\" --project=${PROJECT} # to grant required IAM permissions for MCS" | pv -qL 100
    gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:${PROJECT}.svc.id.goog[gke-mcs/gke-mcs-importer]" --role "roles/compute.networkViewer" --project=${PROJECT}
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\$(gcloud config get-value core/account) # to grant current user cluster admin priviledges" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account) 
    if [ $i -eq 1 ]; then
        echo
        echo "$ kubectl kustomize \"github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0\" | kubectl apply -f - --context=gke-west-1 # to deploy Gateway resources" | pv -qL 100
        kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0" | kubectl apply -f - --context=$CTX
        echo
        echo "$ gcloud alpha container hub ingress enable --config-membership=projects/$PROJECT/locations/$REGION/memberships/$CLUSTER --quiet --project $PROJECT_ID # to enable Multi-cluster Gateway controller and select config cluster" | pv -qL 100
        gcloud alpha container hub ingress enable --config-membership=projects/$PROJECT/locations/$REGION/memberships/$CLUSTER --quiet --project $PROJECT_ID
        echo
        echo "gcloud projects add-iam-policy-binding ${PROJECT} --member \"serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com\" --role \"roles/container.admin\" --project=${PROJECT} # to grant IAM permissions required by Gateway controller" | pv -qL 100
        gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com" --role "roles/container.admin" --project=${PROJECT}
    fi
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x(${i})"   
    export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
    export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
    export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
    export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
    export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
    export REGION=${!GCP_REGION} > /dev/null 2>&1
    export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
    export ZONE=${!GCP_ZONE} > /dev/null 2>&1
    export GCP_MACHINE=$(echo GCP_MACHINE_$(eval "echo $i")) > /dev/null 2>&1
    export MACHINE=${!GCP_MACHINE} > /dev/null 2>&1
    export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
    export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT} --format="value(projectNumber)")
    export IDNS=${PROJECT}.svc.id.goog # used to enable Workload Identity
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster, required for metrics to get displayed on ASM Dashboard
    export PROJECT_ID=${PROJECT}
    export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
    export CLUSTER_ZONE=${ZONE}
    export CLUSTER_NAME=${CLUSTER}
    export CLUSTER_LOCATION=${ZONE}
    gcloud config set project $PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $ZONE > /dev/null 2>&1
    if [ "$i" -eq 1 ]; then
        echo
        echo "$ gcloud beta container clusters delete $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID # to delete cluster" | pv -qL 100
        gcloud beta container clusters delete $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
    else
        echo
        echo "$ gcloud beta container clusters delete $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID # to delete cluster" | pv -qL 100
        gcloud beta container clusters delete $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
    fi
    echo
    echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
    kubectl config use-context $CTX 
    echo
    echo "$ gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID # to retrieve the credentials for cluster" | pv -qL 100
    gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID
    echo
    echo "$ kubectl delete clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\$(gcloud config get-value core/account) # to remove cluster admin priviledges" | pv -qL 100
    kubectl delete clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account) 
    echo
    echo "$ gcloud projects remove-iam-policy-binding ${PROJECT} --member \"serviceAccount:${PROJECT}.svc.id.goog[gke-mcs/gke-mcs-importer]\" --role \"roles/compute.networkViewer\" --project=${PROJECT} # to remove IAM permissions for MCS" | pv -qL 100
    gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${PROJECT}.svc.id.goog[gke-mcs/gke-mcs-importer]" --role "roles/compute.networkViewer" --project=${PROJECT}
    echo
    echo "$ gcloud container hub multi-cluster-services disable --project $PROJECT # to enable MCS" | pv -qL 100
    gcloud container hub multi-cluster-services disable --project $PROJECT
    echo
    gcloud container fleet memberships delete $CLUSTER --quiet --project $PROJECT_ID > /dev/null 2>&1 
    echo "$ gcloud container hub memberships register $CLUSTER --project=$PROJECT --gke-cluster=$ZONE/$CLUSTER --enable-workload-identity --project $PROJECT_ID" | pv -qL 100
    gcloud container hub memberships register $CLUSTER --project=$PROJECT --gke-cluster=$ZONE/$CLUSTER --enable-workload-identity --project $PROJECT_ID
    echo
    echo "$ gcloud projects remove-iam-policy-binding $PROJECT --member user:\"\$(gcloud config get-value core/account)\" --role=roles/editor --role=roles/compute.admin --role=roles/container.admin --role=roles/resourcemanager.projectIamAdmin --role=roles/iam.serviceAccountAdmin --role=roles/iam.serviceAccountKeyAdmin --role=roles/gkehub.admin --project $PROJECT_ID # to ensure user is able to register and connect cluster" | pv -qL 100
    gcloud projects remove-iam-policy-binding $PROJECT --member user:"$(gcloud config get-value core/account)" --role=roles/editor --role=roles/compute.admin --role=roles/container.admin --role=roles/resourcemanager.projectIamAdmin --role=roles/iam.serviceAccountAdmin --role=roles/iam.serviceAccountKeyAdmin --role=roles/gkehub.admin --project $PROJECT_ID

    if [ $i -eq 1 ]; then
        echo
        echo "$ gcloud projects remove-iam-policy-binding ${PROJECT} --member \"serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com\" --role \"roles/container.admin\" --project=${PROJECT} # to remove IAM permissions" | pv -qL 100
        gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com" --role "roles/container.admin" --project=${PROJECT}
        echo
        echo "$ gcloud alpha container hub ingress disable --quiet --project $PROJECT_ID # to enable Multi-cluster Gateway controller and select config cluster" | pv -qL 100
        gcloud alpha container hub ingress disable --quiet --project $PROJECT_ID
        echo
        echo "$ kubectl kustomize \"github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0\" | kubectl delete -f - --context=gke-west-1 # to deploy Gateway resources"
        kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0" | kubectl delete -f - --context=$CTX
    fi
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Create cluster" | pv -qL 100
    echo "2. Set context" | pv -qL 100
    echo "3. Retrieve credentials for cluster" | pv -qL 100
    echo "4. Ensure user is able to register and connect cluster" | pv -qL 100
    echo "5. Enable MCS"
    echo "6. Grant required IAM permissions for MCS"
    echo "7. Grant current user cluster admin priviledges" | pv -qL 100
    echo "8. Enable Ingress for Anthos and select config cluster" | pv -qL 100
fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},4i(${i})"
        echo
        echo "$ cat > \$PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
        echo
        echo "$ \$PROJDIR/asmcli install --project_id \$PROJECT_ID --cluster_name \$CLUSTER --cluster_location \$CLUSTER_LOCATION --fleet_id \$PROJECT_ID --output_dir \$PROJDIR --enable_all --ca mesh_ca --custom_overlay \$PROJDIR/tracing.yaml --custom_overlay \$PROJDIR/asm/istio/options/iap-operator.yaml # to install ASM" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},4(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT} --format="value(projectNumber)")
        export IDNS=${PROJECT}.svc.id.goog # used to enable Workload Identity
        export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster, required for metrics to get displayed on ASM Dashboard
        export PROJECT_ID=${PROJECT}
        export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
        export CLUSTER_ZONE=${ZONE}
        export CLUSTER_NAME=${CLUSTER}
        export CLUSTER_LOCATION=${ZONE}
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID # to retrieve the credentials for cluster" | pv -qL 100
        gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
        echo
        echo "$ cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF
        echo
        sudo apt-get install ncat -y > /dev/null 2>&1 
        echo "$ $PROJDIR/asmcli install --project_id $PROJECT --cluster_name $CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --custom_overlay $PROJDIR/asm/istio/options/iap-operator.yaml # to install ASM" | pv -qL 100
        $PROJDIR/asmcli install --project_id $PROJECT --cluster_name $CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --custom_overlay $PROJDIR/asm/istio/options/iap-operator.yaml
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},4x(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT} --format="value(projectNumber)")
        export IDNS=${PROJECT}.svc.id.goog # used to enable Workload Identity
        export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster, required for metrics to get displayed on ASM Dashboard
        export PROJECT_ID=${PROJECT}
        export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
        export CLUSTER_ZONE=${ZONE}
        export CLUSTER_NAME=${CLUSTER}
        export CLUSTER_LOCATION=${ZONE}
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID # to retrieve the credentials for cluster" | pv -qL 100
        gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
        echo
        echo "$ kubectl label namespace default istio.io/rev # to remove labels" | pv -qL 100
        kubectl label namespace default istio.io/rev-
        echo
        echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to remove webhooks" | pv -qL 100
        kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
        echo
        echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge # to remove the in-cluster control plane" | pv -qL 100
        $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge
        echo && echo
        echo "$  kubectl delete namespace istio-system asm-system --ignore-not-found=true # to remove namespace" | pv -qL 100
        kubectl delete namespace istio-system asm-system --ignore-not-found=true
    else
        export STEP="${STEP},4i"
        echo
        echo "1. Retrieve the credentials for cluster" | pv -qL 100
        echo "2. Configure Istio Operator" | pv -qL 100
        echo "3. Install Anthos Service Mesh" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},5i(${i})"   
        echo
        echo "$ kubectl label namespace default istio-injection=enabled --overwrite # to label namespace" | pv -qL 100 
        echo
        echo "$ kubectl apply -f \$PROJDIR/istio-manifests.yaml # to apply manifests" | pv -qL 100
        echo
        echo "$ kubectl apply -f \$PROJDIR/kubernetes-manifests.yaml # to apply manifests" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},5(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export PROJECT_ID=${PROJECT}
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        kubectl config use-context ${CTX} > /dev/null 2>&1
        gcloud container clusters get-credentials ${CLUSTER} --zone ${ZONE} > /dev/null 2>&1
        cat > $PROJDIR/istio-manifests.yaml <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: istio-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: frontend-route
spec:
  parentRefs:
  - name: istio-gateway
  rules:
  - matches:
    - path:
        value: /
    backendRefs:
    - name: frontend
      port: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: allow-egress-googleapis
spec:
  hosts:
  - "accounts.google.com" # Used to get token
  - "*.googleapis.com"
  ports:
  - number: 80
    protocol: HTTP
    name: http
  - number: 443
    protocol: HTTPS
    name: https
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: allow-egress-google-metadata
spec:
  hosts:
  - metadata.google.internal
  addresses:
  - 169.254.169.254 # GCE metadata server
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "frontend.default.svc.cluster.local"
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
EOF
    cat > $PROJDIR/kubernetes-manifests.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: emailservice
spec:
  selector:
    matchLabels:
      app: emailservice
  template:
    metadata:
      labels:
        app: emailservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/emailservice:v0.9.0
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          periodSeconds: 5
          grpc:
            port: 8080
        livenessProbe:
          periodSeconds: 5
          grpc:
            port: 8080
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: emailservice
spec:
  type: ClusterIP
  selector:
    app: emailservice
  ports:
  - name: grpc
    port: 5000
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkoutservice
spec:
  selector:
    matchLabels:
      app: checkoutservice
  template:
    metadata:
      labels:
        app: checkoutservice
    spec:
      serviceAccountName: default
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: server
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true
          image: gcr.io/google-samples/microservices-demo/checkoutservice:v0.9.0
          ports:
          - containerPort: 5050
          readinessProbe:
            grpc:
              port: 5050
          livenessProbe:
            grpc:
              port: 5050
          env:
          - name: PORT
            value: "5050"
          - name: PRODUCT_CATALOG_SERVICE_ADDR
            value: "productcatalogservice:3550"
          - name: SHIPPING_SERVICE_ADDR
            value: "shippingservice:50051"
          - name: PAYMENT_SERVICE_ADDR
            value: "paymentservice:50051"
          - name: EMAIL_SERVICE_ADDR
            value: "emailservice:5000"
          - name: CURRENCY_SERVICE_ADDR
            value: "currencyservice:7000"
          - name: CART_SERVICE_ADDR
            value: "cartservice:7070"
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: checkoutservice
spec:
  type: ClusterIP
  selector:
    app: checkoutservice
  ports:
  - name: grpc
    port: 5050
    targetPort: 5050
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendationservice
spec:
  selector:
    matchLabels:
      app: recommendationservice
  template:
    metadata:
      labels:
        app: recommendationservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/recommendationservice:v0.9.0
        ports:
        - containerPort: 8080
        readinessProbe:
          periodSeconds: 5
          grpc:
            port: 8080
        livenessProbe:
          periodSeconds: 5
          grpc:
            port: 8080
        env:
        - name: PORT
          value: "8080"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 220Mi
          limits:
            cpu: 200m
            memory: 450Mi
---
apiVersion: v1
kind: Service
metadata:
  name: recommendationservice
spec:
  type: ClusterIP
  selector:
    app: recommendationservice
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
      annotations:
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
    spec:
      serviceAccountName: default
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: server
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true
          image: gcr.io/google-samples/microservices-demo/frontend:v0.9.0
          ports:
          - containerPort: 8080
          readinessProbe:
            initialDelaySeconds: 10
            httpGet:
              path: "/_healthz"
              port: 8080
              httpHeaders:
              - name: "Cookie"
                value: "shop_session-id=x-readiness-probe"
          livenessProbe:
            initialDelaySeconds: 10
            httpGet:
              path: "/_healthz"
              port: 8080
              httpHeaders:
              - name: "Cookie"
                value: "shop_session-id=x-liveness-probe"
          env:
          - name: PORT
            value: "8080"
          - name: PRODUCT_CATALOG_SERVICE_ADDR
            value: "productcatalogservice:3550"
          - name: CURRENCY_SERVICE_ADDR
            value: "currencyservice:7000"
          - name: CART_SERVICE_ADDR
            value: "cartservice:7070"
          - name: RECOMMENDATION_SERVICE_ADDR
            value: "recommendationservice:8080"
          - name: SHIPPING_SERVICE_ADDR
            value: "shippingservice:50051"
          - name: CHECKOUT_SERVICE_ADDR
            value: "checkoutservice:5050"
          - name: AD_SERVICE_ADDR
            value: "adservice:9555"
          # # ENV_PLATFORM: One of: local, gcp, aws, azure, onprem, alibaba
          # # When not set, defaults to "local" unless running in GKE, otherwies auto-sets to gcp
          # - name: ENV_PLATFORM
          #   value: "aws"
          - name: ENABLE_PROFILER
            value: "0"
          # - name: CYMBAL_BRANDING
          #   value: "true"
          # - name: FRONTEND_MESSAGE
          #   value: "Replace this with a message you want to display on all pages."
          # As part of an optional Google Cloud demo, you can run an optional microservice called the "packaging service".
          # - name: PACKAGING_SERVICE_URL
          #   value: "" # This value would look like "http://123.123.123"
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-external
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
spec:
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/paymentservice:v0.9.0
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          grpc:
            port: 50051
        livenessProbe:
          grpc:
            port: 50051
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: paymentservice
spec:
  type: ClusterIP
  selector:
    app: paymentservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice
spec:
  selector:
    matchLabels:
      app: productcatalogservice
  template:
    metadata:
      labels:
        app: productcatalogservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/productcatalogservice:v0.9.0
        ports:
        - containerPort: 3550
        env:
        - name: PORT
          value: "3550"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          grpc:
            port: 3550
        livenessProbe:
          grpc:
            port: 3550
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: productcatalogservice
spec:
  type: ClusterIP
  selector:
    app: productcatalogservice
  ports:
  - name: grpc
    port: 3550
    targetPort: 3550
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
spec:
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/cartservice:v0.9.0
        ports:
        - containerPort: 7070
        env:
        - name: REDIS_ADDR
          value: "redis-cart:6379"
        resources:
          requests:
            cpu: 200m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 128Mi
        readinessProbe:
          initialDelaySeconds: 15
          grpc:
            port: 7070
        livenessProbe:
          initialDelaySeconds: 15
          periodSeconds: 10
          grpc:
            port: 7070
---
apiVersion: v1
kind: Service
metadata:
  name: cartservice
spec:
  type: ClusterIP
  selector:
    app: cartservice
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loadgenerator
spec:
  selector:
    matchLabels:
      app: loadgenerator
  replicas: 1
  template:
    metadata:
      labels:
        app: loadgenerator
      annotations:
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      restartPolicy: Always
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      initContainers:
      - command:
        - /bin/sh
        - -exc
        - |
          echo "Init container pinging frontend: ${FRONTEND_ADDR}..."
          STATUSCODE=$(wget --server-response http://${FRONTEND_ADDR} 2>&1 | awk '/^  HTTP/{print $2}')
          if test $STATUSCODE -ne 200; then
              echo "Error: Could not reach frontend - Status code: ${STATUSCODE}"
              exit 1
          fi
        name: frontend-check
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: busybox:latest
        env:
        - name: FRONTEND_ADDR
          value: "frontend:80"
      containers:
      - name: main
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/loadgenerator:v0.9.0
        env:
        - name: FRONTEND_ADDR
          value: "frontend:80"
        - name: USERS
          value: "10"
        resources:
          requests:
            cpu: 300m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: currencyservice
spec:
  selector:
    matchLabels:
      app: currencyservice
  template:
    metadata:
      labels:
        app: currencyservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/currencyservice:v0.9.0
        ports:
        - name: grpc
          containerPort: 7000
        env:
        - name: PORT
          value: "7000"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          grpc:
            port: 7000
        livenessProbe:
          grpc:
            port: 7000
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: currencyservice
spec:
  type: ClusterIP
  selector:
    app: currencyservice
  ports:
  - name: grpc
    port: 7000
    targetPort: 7000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shippingservice
spec:
  selector:
    matchLabels:
      app: shippingservice
  template:
    metadata:
      labels:
        app: shippingservice
    spec:
      serviceAccountName: default
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/shippingservice:v0.9.0
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          periodSeconds: 5
          grpc:
            port: 50051
        livenessProbe:
          grpc:
            port: 50051
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: shippingservice
spec:
  type: ClusterIP
  selector:
    app: shippingservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cart
spec:
  selector:
    matchLabels:
      app: redis-cart
  template:
    metadata:
      labels:
        app: redis-cart
    spec:
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: redis
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: redis:alpine
        ports:
        - containerPort: 6379
        readinessProbe:
          periodSeconds: 5
          tcpSocket:
            port: 6379
        livenessProbe:
          periodSeconds: 5
          tcpSocket:
            port: 6379
        volumeMounts:
        - mountPath: /data
          name: redis-data
        resources:
          limits:
            memory: 256Mi
            cpu: 125m
          requests:
            cpu: 70m
            memory: 200Mi
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
spec:
  type: ClusterIP
  selector:
    app: redis-cart
  ports:
  - name: tcp-redis
    port: 6379
    targetPort: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adservice
spec:
  selector:
    matchLabels:
      app: adservice
  template:
    metadata:
      labels:
        app: adservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/adservice:v0.9.0
        ports:
        - containerPort: 9555
        env:
        - name: PORT
          value: "9555"
        resources:
          requests:
            cpu: 200m
            memory: 180Mi
          limits:
            cpu: 300m
            memory: 300Mi
        readinessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          grpc:
            port: 9555
        livenessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          grpc:
            port: 9555
---
apiVersion: v1
kind: Service
metadata:
  name: adservice
spec:
  type: ClusterIP
  selector:
    app: adservice
  ports:
  - name: grpc
    port: 9555
    targetPort: 9555
EOF
        echo
        echo "$ kubectl label namespace default istio-injection=enabled --overwrite # to label namespace" | pv -qL 100 
        kubectl label namespace default istio-injection=enabled --overwrite
        echo
        echo "$ kubectl apply -f $PROJDIR/istio-manifests.yaml # to apply manifests" | pv -qL 100
        kubectl -n default apply -f $PROJDIR/istio-manifests.yaml
        echo
        echo "$ kubectl apply -f $PROJDIR/kubernetes-manifests.yaml # to apply manifests" | pv -qL 100
        kubectl -n default apply -f $PROJDIR/kubernetes-manifests.yaml
        sleep 10
        echo
        echo "$ kubectl -n default rollout restart deploy # restart pods in namespace"
        kubectl -n default rollout restart deploy
        echo
        echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n default # to wait for the deployment to finish" | pv -qL 100
        kubectl wait --for=condition=available --timeout=600s deployment --all -n default
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},5x(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export PROJECT_ID=${PROJECT}
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        kubectl config use-context ${CTX} > /dev/null 2>&1
        gcloud container clusters get-credentials ${CLUSTER} --zone ${ZONE} > /dev/null 2>&1
        echo
        echo "$ kubectl label namespace default istio-injection- # to label namespace" | pv -qL 100 
        kubectl label namespace default istio-injection-
        echo
        echo "$ kubectl delete -f $PROJDIR/istio-manifests.yaml # to delete manifests" | pv -qL 100
        kubectl -n default delete -f $PROJDIR/istio-manifests.yaml
        echo
        echo "$ kubectl delete -f $PROJDIR/kubernetes-manifests.yaml # to delete manifests" | pv -qL 100
        kubectl -n default delete -f $PROJDIR/kubernetes-manifests.yaml
    else
        export STEP="${STEP},5i"   
        echo
        echo "1. Label namespace" | pv -qL 100 
        echo "2. Apply manifests" | pv -qL 100
    fi
done 
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: hipster-mcs
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
  - link: \"\$CONFIG_ZONE/\$CONFIG_CLUSTER\"
  - link: \"\$REMOTE_ZONE/\$REMOTE_CLUSTER\"
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: hipster-mci
spec:
  template:
    spec:
      backend:
        serviceName: hipster-mcs
        servicePort: 80
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n default describe MultiClusterIngress hipster-mci # to view ingress configuration" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    for i in 1 2 
    do
        if [ $i -eq 1 ]; then
            export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
            export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
            export PROJECT_ID=${PROJECT}
            export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
            export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
            export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
            export ZONE=${!GCP_ZONE} > /dev/null 2>&1
            export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
            export CONFIG_CLUSTER=${CLUSTER} > /dev/null 2>&1
            export CONFIG_CTX="${CTX}" > /dev/null 2>&1
            export CONFIG_ZONE=${ZONE} > /dev/null 2>&1
        else
            export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
            export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
            export PROJECT_ID=${PROJECT}
            export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
            export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
            export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
            export ZONE=${!GCP_ZONE} > /dev/null 2>&1
            export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
            export REMOTE_CLUSTER=${CLUSTER} > /dev/null 2>&1
            export REMOTE_CTX="${CTX}" > /dev/null 2>&1
            export REMOTE_ZONE=${ZONE} > /dev/null 2>&1
        fi
    done 
    gcloud config set project $PROJECT > /dev/null 2>&1
    kubectl config use-context ${CONFIG_CTX} > /dev/null 2>&1
    gcloud container clusters get-credentials ${CONFIG_CLUSTER} --zone ${CONFIG_ZONE} --project $PROJECT_ID > /dev/null 2>&1
    echo
    echo "$ kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: hipster-mcs
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
  - link: \"$CONFIG_ZONE/$CONFIG_CLUSTER\"
  - link: \"$REMOTE_ZONE/$REMOTE_CLUSTER\"
EOF" | pv -qL 100
    kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: hipster-mcs
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
  - link: "$CONFIG_ZONE/$CONFIG_CLUSTER"
  - link: "$REMOTE_ZONE/$REMOTE_CLUSTER"
EOF
    echo
    echo "$ kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: hipster-mci
spec:
  template:
    spec:
      backend:
        serviceName: hipster-mcs
        servicePort: 80
EOF" | pv -qL 100
    kubectl -n default apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: hipster-mci
spec:
  template:
    spec:
      backend:
        serviceName: hipster-mcs
        servicePort: 80
EOF
    sleep 30
    echo
    echo "$ kubectl -n default describe MultiClusterIngress hipster-mci # to view ingress configuration" | pv -qL 100
    kubectl -n default describe MultiClusterIngress hipster-mci
    echo
    echo "It may take up to 10 mins for ingress to be ready" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    for i in 1 2 
    do
        if [ $i -eq 1 ]; then
            export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
            export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
            export PROJECT_ID=${PROJECT}
            export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
            export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
            export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
            export ZONE=${!GCP_ZONE} > /dev/null 2>&1
            export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
            export CONFIG_CLUSTER=${CLUSTER} > /dev/null 2>&1
            export CONFIG_CTX="${CTX}" > /dev/null 2>&1
            export CONFIG_ZONE=${ZONE} > /dev/null 2>&1
        else
            export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
            export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
            export PROJECT_ID=${PROJECT}
            export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
            export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
            export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
            export ZONE=${!GCP_ZONE} > /dev/null 2>&1
            export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
            export REMOTE_CLUSTER=${CLUSTER} > /dev/null 2>&1
            export REMOTE_CTX="${CTX}" > /dev/null 2>&1
            export REMOTE_ZONE=${ZONE} > /dev/null 2>&1
        fi
    done 
    gcloud config set project $PROJECT > /dev/null 2>&1
    kubectl config use-context ${CONFIG_CTX} > /dev/null 2>&1
    gcloud container clusters get-credentials ${CONFIG_CLUSTER} --zone ${CONFIG_ZONE} --project $PROJECT_ID > /dev/null 2>&1
    echo
    echo "$ kubectl -n default delete MultiClusterService hipster-mcs # to delete MCS"
    kubectl -n default delete MultiClusterService hipster-mcs
    echo
    echo "$ kubectl -n default delete MultiClusterIngress hipster-mci # to delete MCI"
    kubectl -n default delete MultiClusterIngress hipster-mci
else
    export STEP="${STEP},6i"
    echo
    echo "1. Configure Multi Cluster Service" | pv -qL 100
    echo "2. View ingress configuration" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud
 
Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
