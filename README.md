# Demo k8s deployment for webblast

This experimental demo allows one to run BLAST on a single-node GCP kubernetes cluster with a simple web
interface. BLASTDBs are pre-loaded on a persistent disk and made available to
the cluster.

## Instructions

These should work on the GCP cloud shell or a machine with kubectl, docker,
git, make, envsubst, and the GCP CLI SDK. This assumes the necessary GCP
account roles/permissions are set (e.g.: GCE, GKE).

1. Clone this repo: `git clone https://github.com/christiam/web-blast-k8s`
1. `cd web-blast-k8s`
1.  Please set the `GCP_PROJECT`, `GCP_REGION` and `GCP_ZONE` values in the
`Makefile`.
1. Run `make all`. This will
   1. create the cluster
   1. set up the persistent disk
   1. deploy the application
   1. show k8s cluster information
   1. Check that the web application is running (note that it may take a
      minute to set this up).
1. To access the web application, point your web browser to the IP address provided
by the output of the command `make ip`. This webapp supports the [NCBI Common
URL API](https://ncbi.github.io/blast-cloud/dev/api.html).
1. To shutdown all the resources instantiated by this demo, run `make distclean`.

By default the resulting k8s cluster will be named `test-cluster-$USER`, where `$USER` is
your unix user name. The persistent disk will be named `test-cluster-$USER-pd`.

### Configuration

The following application/cluster elements can be configured; most of these are `Makefile` variables:

* `MTYPE`: Machine type to use in the cluster.
* `PD_SIZE`: Size of the persistent disk to initialize.
* `blast_dbs` in `setup-blastdbs-pd.sh`: BLASTDBs to download into the
  persistent disk.

### Developer notes

* The script `setup-blastdbs-pd.sh` hard codes the names of the BLAST
  databases to show. Please update these if needed. These must be available to
  the `update_blastdb.pl` script from
  [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download).

## Requirements

* [GCP SDK CLI](https://cloud.google.com/sdk)
* [docker](https://docs.docker.com/install/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [webblast docker image](https://hub.docker.com/repository/docker/christiam/webblast)
* [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) from the GNU gettext utilities package
* [GNU make](https://www.gnu.org/software/make/)
* [git](https://git-scm.com/)
