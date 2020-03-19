# Makefile for setting up a k8s cluster to run WebBLAST
# Author: Christiam Camacho (christiam.camacho@gmail.com)

SHELL=/bin/bash
.PHONY: all clean distclean check

GCP_PROJECT=
GCP_REGION=us-east4
GCP_ZONE=us-east4-b

DEPLOYMENT_NAME=$(shell awk '/name:/ {print $$2}' specs/deployment.yaml | head -1)
SERVICE_NAME=$(shell awk '/name:/ {print $$2}' specs/svc.yaml | head -1)

CLUSTER_NAME?=test-cluster-${USER}
DISK_NAME=${CLUSTER_NAME}-pd
NUM_NODES?=1	# GCP default is 3
PD_SIZE?=1000G	# needed for nr, nt, swissprot, defined in setup-blastdbs-pd.sh
MTYPE=n1-standard-32

USE_PREEMPTIBLE=1
VPATH=specs

%.yaml: %.yaml.template
	PD_SIZE=${PD_SIZE} envsubst < $< > $@

ifdef USE_PREEMPTIBLE
PREEMPTIBLE=--preemptible
endif

all: setup_pd create_cluster deploy show check
	kubectl get all
	echo "Don't forget to run make distclean to clean up"

.PHONY: init
init:
	gcloud config set project ${GCP_PROJECT}
	gcloud config set compute/zone ${GCP_ZONE}
	gcloud config set compute/region ${GCP_REGION}

.PHONY: setup_pd
setup_pd: init
	./setup-blastdbs-pd.sh ${CLUSTER_NAME} ${GCP_ZONE} ${PD_SIZE}

# N.B.: times are in UTC
.PHONY: create_cluster
create_cluster: init
	gcloud container clusters create ${CLUSTER_NAME} \
		--disk-size=100GB \
		--labels=creator=${USER} \
		--maintenance-window=06:00 \
		--metadata project=blast,app=${DEPLOYMENT_NAME} \
		--num-nodes ${NUM_NODES} ${PREEMPTIBLE} \
		--machine-type ${MTYPE} \
		--scopes cloud-platform
	gcloud container clusters get-credentials ${CLUSTER_NAME}

# Create the k8s deployment and create a k8s service to expose the deployment to the world
.PHONY: deploy
deploy: specs/pv.yaml specs/pvc.yaml
	kubectl apply -f specs

# Show the cluster's primary IP address
.PHONY: ip
ip:
	@echo $(shell kubectl get service ${SERVICE_NAME} -o json | jq  -r .status.loadBalancer.ingress[0].ip)

check:
	curl -s http://$(shell kubectl get service ${SERVICE_NAME} -o json | jq  -r .status.loadBalancer.ingress[0].ip)

clean:
	-kubectl delete -f specs

distclean: clean init
	-yes | gcloud container clusters delete ${CLUSTER_NAME}
	-yes | gcloud compute disks delete ${DISK_NAME}

.PHONY: show
show:
	-kubectl describe -f specs
	-kubectl get pods -l app=webblast
	-kubectl get all -l app=webblast
	-kubectl get all
	-gcloud container clusters list
	-gcloud compute instances list
	-gcloud compute disks list

# Note: this doesn't work well right now, as the volumes are not set properly
# for all pods to share the spool area
#scale:
#	kubectl scale --replicas=${NUM_NODES} -f specs/deployment.yaml
