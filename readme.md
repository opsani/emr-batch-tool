# The EMR Batch Timing Tool

This tool exists to allow you to run an arbitrary Python Jupyter notebook on Amazon Elastic Map Reduce (EMR) from the command line. (COMING SOON!) Additional modification to the script should allow us to be able to run it with a variety of instance groups and to time the results. This script times work done over a variety of EMR cluster statuses.

## EMR Cluster Statuses

These are the statuses currently in use. **BOLD** statuses are the statuses that we are looking at in the script.

**STARTING – In this state, cluster provisions, starts, and configures EC2 instances**
BOOTSTRAPPING – In this state cluster is executing the Bootstrap process
**RUNNING – State in which cluster is currently being run**
WAITING – In this state cluster is currently active, but there are no steps to run
**TERMINATING - Shut down of cluster has started**
TERMINATED - The cluster is shut down without any error
TERMINATED_WITH_ERRORS - The cluster is shut down with errors.

We look at the time it takes to *start* the cluster. Then we measure how long it takes the cluster to *run* a job. Then we measure how long it takes to *terminate* a job. We don't anticipate our cluster to ever sit in the waiting stage. If a cluster is not actively running, we terminate it.

## Prep

Check your credentials and make sure you are logged in as the right user. Even after using `aws sts get-caller-identity`, you may need to create default roles. (The script does this for you.)

_(Security Token Service should always work irrespective of your IAM permissions.)_

**This script also depends on jq for JSON parsing. Make sure that jq is in your path.**

## What the Script Does

### Prepare the Environment

First we set some variables that make life easier. 

```
EMR_BATCH_WORKING_BUCKET=emr-batch-tool-demo-1
EMR_BATCH_RESULTS_FOLDER=results-folder
EMR_BATCH_REGION=us-east-1
AWS_EMR_RELEASE_VERSION=(6.0.0)
```

We can easily extend this to any of the other variables that we would like to change from outside of the script. Rather than passing in a bunch of arguments, we opt to use environment variables instead.

We create an S3 bucket to work with.

`aws s3api create-bucket --bucket ${EMR_BATCH_WORKING_BUCKET} --region ${EMR_BATCH_REGION} > /dev/null 2>&1`

You can name it whatever you want, but because AWS EMR uses Hadoop, you can't use spaces in the name.

Then we create a folder to store the output data

`aws s3api put-object --bucket ${EMR_BATCH_WORKING_BUCKET} --key ${EMR_BATCH_RESULTS_FOLDER} > /dev/null 2>&1`


### Build Cluster

Then we build the cluster. As we expand this tool, this is where we will want to change some things into environment variables and add additional flags to this particular invocation. In particular, we will want to add "steps" and data resources to consume for the actual job. (This version has zero payload.)

```
aws emr create-cluster \
--release-label emr-${AWS_EMR_RELEASE_VERSION} \
--region ${EMR_BATCH_REGION} \
--instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large > createClusterResult.json
```

You will notice that we chose to save the output of the last result to a JSON file rather than directly capturing the cluster-id. This is not because of some clever reason, but instead because I simply couldn't figure out how to make the invocation work while also giving me the data in a variable properly.

`WORKING_CLUSTER_ID=$(cat createClusterResult.json | jq -r '.ClusterId')`

From that point on, we simply need check the current status of the cluster, which will return one of the statuses above.

`CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')`

We do that to make sure that the cluster has completely come up, and then again to verify that the cluster is running the batch job.

# Teardown

When we are done, we start measuring the time it takes to tear everything down. We start by tearing down the cluster:

`aws emr terminate-clusters --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} > /dev/null 2>&1`

Then we obliterate what is in S3. The following command recursively tears down an entire bucket. Do this AFTER you have terminated the cluster, unless there is a compelling reason to keep the data around.

`aws s3 rb --force s3://${EMR_BATCH_WORKING_BUCKET}`
