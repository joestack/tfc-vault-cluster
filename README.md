# tfe-vault-cluster

Deploying a Vault HA Cluster (autounseal, raft-storage) on AWS based on the following prerequisites:

* AWS credentials
* a SSH key available within your selected AWS region
* a Route53 zone to be able to create some DNS records

Just have a look into `variables.tf` and change it to your needs.

Once the deployment is applied you need to login via SSH to an instance and run `vault operator init` to start the cluster.
