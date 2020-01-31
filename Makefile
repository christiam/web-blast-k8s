# Makefile for setting up a k8s cluster to run WebBLAST
# Author: Christiam Camacho (christiam.camacho@gmail.com)

SHELL=/bin/bash
.PHONY: all clean distclean check

GCP_PROJECT=
GCP_REGION=us-east4
GCP_ZONE=us-east4-b

DEPLOYMENT_NAME=webblast-deployment
CLUSTER_NAME?=test-cluster-${USER}
DISK_NAME=${CLUSTER_NAME}-pd
NUM_NODES?=2	# GCP default is 3
USE_PREEMPTIBLE=1

ifdef USE_PREEMPTIBLE
PREEMPTIBLE=--preemptible
endif

all: create setup_pd deploy show check
	kubectl get all
	echo "Don't forget to run make distclean to clean up"

.PHONY: init
init:
	gcloud config set project ${GCP_PROJECT}
	gcloud config set compute/zone ${GCP_ZONE}
	gcloud config set compute/region ${GCP_REGION}

.PHONY: setup_pd
setup_pd: init
	./setup-blastdbs-pd.sh ${CLUSTER_NAME} ${GCP_ZONE}

# N.B.: times are in UTC
.PHONY: create
create: init
	gcloud container clusters create ${CLUSTER_NAME} \
		--disk-size=100GB \
		--labels=creator=${USER} \
		--maintenance-window=06:00 \
		--metadata project=blast,app=${DEPLOYMENT_NAME} \
		--num-nodes ${NUM_NODES} ${PREEMPTIBLE} \
		--scopes cloud-platform
	gcloud container clusters get-credentials ${CLUSTER_NAME}

# Create the k8s deployment and create a k8s service to expose the deployment to the world
.PHONY: deploy
deploy:
	kubectl apply -f specs

.PHONY: ip
ip:
	echo $(shell kubectl get service ${DEPLOYMENT_NAME} -o json | jq  -r .status.loadBalancer.ingress[0].ip)

check:
	curl -s http://$(shell kubectl get service ${DEPLOYMENT_NAME} -o json | jq  -r .status.loadBalancer.ingress[0].ip)

clean:
	-kubectl delete -f specs
	#-kubectl delete service ${DEPLOYMENT_NAME}

distclean: clean init
	-yes | gcloud container clusters delete ${CLUSTER_NAME}
	-yes | gcloud compute disks delete ${DISK_NAME}

.PHONY: show
show:
	-kubectl describe -f specs
	-kubectl get pods -l app=webblast
	-kubectl get all -l app=webblast
	-kubectl get all
	gcloud container clusters list


#update: deployment-scale.yaml
#	kubectl apply -f $<
