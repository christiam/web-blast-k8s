# Makefile for setting up a k8s cluster to run WebBLAST
# Author: Christiam Camacho (christiam.camacho@gmail.com)

SHELL=/bin/bash
.PHONY: all clean distclean check

GCP_PROJECT?=camacho
GCP_REGION?=us-east4
GCP_ZONE?=us-east4-b

DEPLOYMENT_NAME=$(shell awk '/name:/ {print $$2}' specs/deployment.yaml | head -1)
SERVICE_NAME=$(shell awk '/name:/ {print $$2}' specs/svc.yaml | head -1)

CLUSTER_NAME?=test-cluster-${USER}
NUM_NODES?=1	# GCP default is 3
PD_SIZE?=1G
DB?=swissprot
MTYPE=n1-standard-32

USE_PREEMPTIBLE=1
VPATH=specs

%.yaml: %.yaml.template
	DB=${DB} \
	PD_SIZE=${PD_SIZE} \
	envsubst < $< > $@

ifdef USE_PREEMPTIBLE
PREEMPTIBLE=--preemptible
endif

all: deploy check
	make k8s
	echo "Don't forget to run make clean to clean up"

all_gcp: create_cluster deploy_gcp show check
	make k8s
	echo "Don't forget to run make distclean to clean up"

.PHONY: k8s
k8s:
	-kubectl get pv,pvc,job,pod,deploy,svc,sc -o wide 

.PHONY: init
init:
	gcloud config set project ${GCP_PROJECT}
	gcloud config set compute/zone ${GCP_ZONE}
	gcloud config set compute/region ${GCP_REGION}

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
deploy: specs/pvc.yaml specs/job-init-pv.yaml
	kubectl apply -f <(grep -v storageClassName $<)
	kubectl apply -f specs/job-init-pv.yaml
	time kubectl wait --for=condition=complete -f specs/job-init-pv.yaml --timeout=3m
	kubectl apply -f specs/svc.yaml
	kubectl apply -f specs/deployment.yaml

# order matters so that resources are created properly
.PHONY: deploy_gcp
deploy_gcp: specs/pvc.yaml specs/job-init-pv.yaml
	kubectl apply -f specs/storage-gcp.yaml
	kubectl apply -f $<
	kubectl apply -f specs/job-init-pv.yaml
	time kubectl wait --for=condition=complete -f specs/job-init-pv.yaml --timeout=3m
	kubectl apply -f specs/svc.yaml
	kubectl apply -f specs/deployment.yaml

# Show the cluster's primary IP address
# FIXME: allow hostaname, if IP is null
.PHONY: ip
ip:
	@echo $(shell kubectl get svc ${SERVICE_NAME} -o json | jq  -r '.status.loadBalancer.ingress[0] | ( .hostname, .ip )' | grep -v null)

check:
	curl -s http://$(shell kubectl get svc ${SERVICE_NAME} -o json | jq -r '.status.loadBalancer.ingress[0] | .hostname, .ip' | grep -v null)
	-kubectl delete -f specs/job-show-blastdbs.yaml
	kubectl apply -f specs/job-show-blastdbs.yaml
	kubectl wait --for=condition=complete -f specs/job-show-blastdbs.yaml
	kubectl get pod -o name -l app=test | xargs -t -I{} -n1 kubectl logs {} --timestamps

logs:
	kubectl get pod -o name -l app=setup | xargs -t -I{} -n1 kubectl logs {} --timestamps
	kubectl get pod -o name -l app=test | xargs -t -I{} -n1 kubectl logs {} --timestamps
	kubectl get pod -o name -l app=webblast | xargs -t -I{} -n1 kubectl logs {} --timestamps

#clean2:
#	-kubectl delete -f specs/job-init-pv.yaml
#	-kubectl delete -f specs/job-show-blastdbs.yaml
#	-kubectl delete -f specs/deployment.yaml
#	-kubectl delete -f specs/svc.yaml
#	-kubectl delete -f specs/pvc.yaml
#	${RM} specs/job-init-pv.yaml specs/pvc.yaml

clean:
	-kubectl delete -f specs
	${RM} specs/job-init-pv.yaml specs/pvc.yaml

distclean: clean init
	-yes | gcloud container clusters delete ${CLUSTER_NAME}

.PHONY: show
show: k8s
	-kubectl describe -f specs
	-gcloud container clusters list
	-gcloud compute instances list
	-gcloud compute disks list

# Note: this doesn't work well right now, as the volumes are not set properly
# for all pods to share the spool area
#scale:
#	kubectl scale --replicas=${NUM_NODES} -f specs/deployment.yaml
