#!/bin/bash

spin()
{
  spinner="/|\\-/|\\-"
  while :
  do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 1
    done
  done
}

echo "EMR Batch Timing Tool ⏲"

# Spin up the Cluster
SECONDS_AT_START=$SECONDS

EMR_BATCH_WORKING_BUCKET=emr-batch-tool-demo-1
EMR_BATCH_RESULTS_FOLDER=results-folder
EMR_BATCH_REGION=us-east-1
AWS_EMR_RELEASE_VERSION=(6.0.0)

## Create S3 Bucket
echo "Creating the S3 Bucket... 💾"
aws s3api create-bucket --bucket ${EMR_BATCH_WORKING_BUCKET} --region ${EMR_BATCH_REGION} > /dev/null 2>&1

## Create a folder to store the output data
aws s3api put-object --bucket ${EMR_BATCH_WORKING_BUCKET} --key ${EMR_BATCH_RESULTS_FOLDER} > /dev/null 2>&1

## Ensure we have roles to create the cluster.
aws emr create-default-roles > /dev/null 2>&1


echo "Creating a cluster... ⚙️"

WORKING_CLUSTER_ID=$(aws emr create-cluster \
--release-label emr-${AWS_EMR_RELEASE_VERSION} \
--region ${EMR_BATCH_REGION} \
--instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large | jq -r '.ClusterId')

CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
echo "Cluster current status: $CLUSTER_CURRENT_STATUS"
if [[ "$CLUSTER_CURRENT_STATUS" == "STARTING" ]]; then
    # Start the Spinner:
    spin &
    # Make a note of its Process ID (PID):
    SPIN_PID=$!
    # Kill the spinner on any signal, including our own exit.
    trap "kill -9 $SPIN_PID" `seq 0 15`
    while true; do
        CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
        [[ "$CLUSTER_CURRENT_STATUS" == "STARTING" ]] || break
        # Pull the status every two seconds.
        sleep 2
    done
    kill -9 $SPIN_PID
else
    echo "❌Unexpected error with AWS EMR Cluster Creation. Expected 'STARTING' Status. Instead, received $CLUSTER_CURRENT_STATUS"
    exit 1
fi

# Start Executing the Job
SECONDS_AT_JOB_START=$SECONDS

CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
echo "Cluster current status: $CLUSTER_CURRENT_STATUS"
if [[ "$CLUSTER_CURRENT_STATUS" == "RUNNING" ]]; then
    echo "Job is running. 🏃🏻‍♂️"
    # Start the Spinner:
    spin &
    # Make a note of its Process ID (PID):
    SPIN_PID=$!
    # Kill the spinner on any signal, including our own exit.
    trap "kill -9 $SPIN_PID" `seq 0 15`
    while true; do
        CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
        [[ "$CLUSTER_CURRENT_STATUS" == "RUNNING" ]] || break
        # Pull the status every two seconds.
        sleep 2
    done
    kill -9 $SPIN_PID
fi

# Tear Down the Cluster
SECONDS_AT_JOB_FINISH=$SECONDS

aws emr terminate-clusters --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} > /dev/null 2>&1
aws s3 rb --force s3://${EMR_BATCH_WORKING_BUCKET}

#while true; do
#    CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
#    [[$CLUSTER_CURRENT_STATUS != "TERMINATING"]] || break 
#done

# Teardown Complete
SECONDS_AT_TEARDOWN_COMPLETION=$SECONDS

echo "Timing Summary"
echo "Total Time (in seconds): $(($SECONDS_AT_TEARDOWN_COMPLETION - $SECONDS_AT_START))"
echo "Cluster Spin-up Time (in seconds): $(($SECONDS_AT_JOB_START - $SECONDS_AT_START))"
echo "Cluster Teardown Time (in seconds): $(($SECONDS_AT_TEARDOWN_COMPLETION - $SECONDS_AT_JOB_FINISH))"
echo "Job Execution Time (in seconds): $(($SECONDS_AT_JOB_FINISH - $SECONDS_AT_JOB_START))"