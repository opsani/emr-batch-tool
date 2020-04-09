###############################################
# EMR Batch Tool by Opsani
# © 2020 Opsani
#
# This script is meant to be a frame
# from which you can prepare your own
# AWS EMR Batch jobs to be optimized
# using the Opsani Continous
# Optimization Engine (OCO).
# 
###############################################

#!/bin/bash
echo "EMR Batch Tool"

# Spin up the Cluster
SECONDS_AT_START=$SECONDS

### ❗️Change these settings to reflect your application need.
EMR_BATCH_WORKING_BUCKET=emr-batch-tool-demo-1
EMR_BATCH_RESULTS_FOLDER=results-folder
EMR_BATCH_REGION=us-east-1
AWS_EMR_RELEASE_VERSION=(6.0.0)

### ❗️Change these portions if you need to do additional work to prepare your data to be in a particular place.
## Create S3 Bucket
echo "Creating the S3 Bucket..."
aws s3api create-bucket --bucket ${EMR_BATCH_WORKING_BUCKET} --region ${EMR_BATCH_REGION} > /dev/null 2>&1

## Create a folder to store the output data
aws s3api put-object --bucket ${EMR_BATCH_WORKING_BUCKET} --key ${EMR_BATCH_RESULTS_FOLDER} > /dev/null 2>&1

## Ensure we have roles to create the cluster.
aws emr create-default-roles > /dev/null 2>&1


echo "Creating a cluster..."

### ❗️This is where you will start your EMR job.
### ❗️Modify the command as needed. Please remember to keep the auto-terminate flag.
#
# EXAMPLE:
# The example command below creates a cluster named Jupyter on EMR inside VPC with EMR version 5.2.1 and Hadoop, Hive, Spark, Ganglia (an interesting tool to monitor your cluster) installed.
# 
# aws emr create-cluster --release-label emr-5.2.1 \
# --name 'Jupyter on EMR inside VPC' \
# --applications Name=Hadoop Name=Hive Name=Spark Name=Ganglia \
# --auto-terminate \
# --ec2-attributes \
# KeyName=yourKeyName,InstanceProfile=EMR_EC2_DefaultRole,SubnetId=yourPrivateSubnetIdInsideVpc,AdditionalMasterSecurityGroups=yourSG \
# --service-role EMR_DefaultRole \
# --instance-groups \
#     InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.xlarge \
#     InstanceGroupType=CORE,InstanceCount=2,BidPrice=0.1,InstanceType=m4.xlarge \
# --region yourRegion \
# --log-uri s3://yourBucketForLogs \
# --bootstrap-actions \
#   Name='Install Jupyter',Path="s3://yourBootstrapScriptOnS3/bootstrap.sh"

WORKING_CLUSTER_ID=$(aws emr create-cluster \
--auto-terminate \
--release-label emr-${AWS_EMR_RELEASE_VERSION} \
--region ${EMR_BATCH_REGION} \
--instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large | jq -r '.ClusterId')

# This monitors when the cluster is starting.
CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
echo "Cluster current status: $CLUSTER_CURRENT_STATUS"
if [[ "$CLUSTER_CURRENT_STATUS" == "STARTING" ]]; then
    while true; do
        CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
        [[ "$CLUSTER_CURRENT_STATUS" == "STARTING" ]] || break
        # Poll the status every two seconds.
        sleep 2
        echo -n "."
    done
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
    while true; do
        CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
        [[ "$CLUSTER_CURRENT_STATUS" == "RUNNING" ]] || break
        # Pull the status every two seconds.
        sleep 2
        echo -n "."
    done
fi

# Tear Down the Cluster
# ❗️This is where you will do whatever you need to reset the state of your data to the orginal state (if needed).
SECONDS_AT_JOB_FINISH=$SECONDS

aws emr terminate-clusters --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} > /dev/null 2>&1
aws s3 rb --force s3://${EMR_BATCH_WORKING_BUCKET}

while true; do
    CLUSTER_CURRENT_STATUS=$(aws emr describe-cluster --cluster-id ${WORKING_CLUSTER_ID} --region ${EMR_BATCH_REGION} | jq -r --arg WORKING_CLUSTER_ID "$WORKING_CLUSTER_ID" '.[] | select(.Id==$WORKING_CLUSTER_ID).Status.State')
    [[$CLUSTER_CURRENT_STATUS != "TERMINATING"]] || break 
    echo -n "."
done

# Teardown Complete
SECONDS_AT_TEARDOWN_COMPLETION=$SECONDS

echo "Timing Summary"
echo "Total Time (in seconds): $(($SECONDS_AT_TEARDOWN_COMPLETION - $SECONDS_AT_START))"
echo "Cluster Spin-up Time (in seconds): $(($SECONDS_AT_JOB_START - $SECONDS_AT_START))"
echo "Cluster Teardown Time (in seconds): $(($SECONDS_AT_TEARDOWN_COMPLETION - $SECONDS_AT_JOB_FINISH))"
echo "Job Execution Time (in seconds): $(($SECONDS_AT_JOB_FINISH - $SECONDS_AT_JOB_START))"
