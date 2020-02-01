# Demo k8s deployment for webblast

This experimental demo allows one to run BLAST on a GCP kubernetes cluster with a simple web
interface. BLASTDBs are pre-loaded on a persistent disk and made available to
the cluster.

## Developer notes

* The script `setup-blastdbs-pd.sh` hard codes the names of the BLAST
  databases to show. Please update these if needed. These must be available to
  the `update_blastdb.pl` script for
  [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download).

## Instructions

Please set the `GCP_PROJECT`, `GCP_REGION` and `GCP_ZONE` values in the
`Makefile`.

Afterwards run `make all` to:

* create the cluster
* set up the persistent disk
* deploy the application
* show k8s cluster information
* Check that the web application is running.

To see the web application, point your web browser to the IP address provided
by the output of the command `make ip`.

To shutdown all the resources instantiated by this demo, run `make distclean`.

## Requirements

* [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) from the GNU gettext utilities package
