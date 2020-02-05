#!/bin/bash -xeu
# Script to set up a persistent disk with BLASTDBs

name=${1:-"$USER-test"}
blast_docker=ncbi/blast:latest
create_date=$(date +%F-%T | tr : - )
labels="created=${create_date},owner=${USER},project=elastic-blast,maintainer=camacho,creator=${USER}"
zone=${2:-"us-east4-b"}
mtype=n1-standard-32
disk_size=${3:-"1000GB"}
disk_type=pd-ssd
#disk_type=pd-standard
mount_dir=/mnt/disks/blast_dbs
#blast_dbs="nt nr swissprot"
blast_dbs=swissprot

# create persistent dis:
time gcloud compute disks create --size=$disk_size --zone=$zone $name-pd --labels $labels --type $disk_type

# create the setup vm:
time gcloud compute instances create-with-container $name-vm --container-image $blast_docker --zone $zone --machine-type $mtype --labels $labels
# attach persistent disk the the setup vm:
time gcloud compute instances attach-disk $name-vm --disk $name-pd --zone $zone
sleep 30 # give it time for the disk to attach, instance to set up ssh

# format disk
device=$(gcloud compute ssh $name-vm --zone $zone --command "lsblk -din | grep -v sda | awk '{print \$1}' ")
time gcloud compute ssh $name-vm --zone $zone -- sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/${device}

# create mount directory, set permissions and mount the disk
time gcloud compute ssh $name-vm --zone $zone -- "sudo mkdir -p $mount_dir && sudo chmod a+rx $mount_dir && sudo mount -o discard,defaults /dev/sdb $mount_dir"

# download BLASTDBs:
time gcloud compute ssh $name-vm --zone $zone -- docker run -w /blast/blastdb -v $mount_dir:/blast/blastdb:rw $blast_docker update_blastdb.pl $blast_dbs --verbose --verbose --verbose --verbose --verbose
set +e
time gcloud compute ssh $name-vm --zone $zone -- docker run -v $mount_dir:/blast/blastdb:ro $blast_docker blastdbcmd -info -db nt
time gcloud compute ssh $name-vm --zone $zone -- docker run -v $mount_dir:/blast/blastdb:ro $blast_docker blastdbcmd -info -db nr
time gcloud compute ssh $name-vm --zone $zone -- docker run -v $mount_dir:/blast/blastdb:ro $blast_docker blastdbcmd -info -db swissprot

# detach the disk:
time gcloud compute ssh $name-vm --zone $zone -- sudo umount $mount_dir
time gcloud compute instances detach-disk $name-vm --disk $name-pd --zone $zone

# stop the vm:
time gcloud compute instances stop $name-vm --zone $zone 
# delete the instance:
time yes | gcloud compute instances delete $name-vm --zone $zone


