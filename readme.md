Check your credentials and make sure you are logged in as the right user using `aws sts get-caller-identity`.

_(Security Token Service should always work irrespective of your IAM permissions.)_

# Prep

Set some variables that make life easier. 

```
EMR_BATCH_WORKING_BUCKET=emr-batch-tool-demo-1
EMR_BATCH_RESULTS_FOLDER=results-folder
EMR_BATCH_REGION=us-east-2
AWS_EMR_RELEASE_VERSION=(6.0.0)
```

Create an S3 bucket.

`aws s3api create-bucket --bucket ${EMR_BATCH_RESULTS_BUCKET} --region ${EMR_BATCH_REGION}`

You can name it whatever you want, but because AWS EMR uses Hadoop, you can't use spaces in the name.

Create a folder to store the output data

`aws s3api put-object --bucket ${EMR_BATCH_RESULTS_BUCKET} --key ${EMR_BATCH_RESULTS_FOLDER}`

Gotta run as someone I guess?

`aws emr create-default-roles`

# Build Cluster

```
aws emr create-cluster \
--release-label emr-${AWS_EMR_RELEASE_VERSION} \
--region ${EMR_BATCH_REGION} \
--instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large
```

# Teardown

This recursively tears down an entire bucket.

`aws s3 rb --force s3://${EMR_BATCH_RESULTS_BUCKET}`

----








----













```
AWS_EMR_RELEASE_VERSION=$(6.0.0)

aws emr create-cluster --release-label emr-${AWS_EMR_RELEASE_VERSION} \
  --name 'My emr-5.12.1 cluster' \
  --applications Name=Hadoop Name=Hive Name=Spark Name=Pig Name=Tez Name=Ganglia Name=Presto \
  --region us-east-1 \
  --instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large \
  --log-uri s3://${EMR_BATCH_WORKING_BUCKET}/emr-logs/ \
  --bootstrap-actions \
    Name='Install Jupyter notebook'
    Path="s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/install-jupyter-emr5.sh", 
    Args=[--r,--julia,--toree,--torch,--ruby,--ds-packages,--ml-packages,--python-packages,'ggplot nilearn',--port,8885,--password,jupyter,--jupyterhub,--jupyterhub-port,8005,--cached-install,--notebook-dir,s3://${EMR_BATCH_WORKING_BUCKET}/notebooks/,--copy-samples]
    ```




```
AWS_EMR_RELEASE_VERSION=$(6.0.0)

aws emr create-cluster --release-label emr-${AWS_EMR_RELEASE_VERSION} \
  --name 'My emr-5.12.1 cluster' \
  --applications Name=Hadoop Name=Hive Name=Spark Name=Pig Name=Tez Name=Ganglia Name=Presto \
  --region us-east-1 \
  --use-default-roles --ec2-attributes KeyName=<your-ec2-key> \ 
  --instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large \
  --log-uri s3://<your-s3-bucket>/emr-logs/ \
  --bootstrap-actions \
    Name='Install Jupyter notebook'
    Path="s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/install-jupyter-emr5.sh", 
    Args=[--r,--julia,--toree,--torch,--ruby,--ds-packages,--ml-packages,--python-packages,'ggplot nilearn',--port,8885,--password,jupyter,--jupyterhub,--jupyterhub-port,8005,--cached-install,--notebook-dir,s3://<your-s3-bucket>/notebooks/,--copy-samples]
    ```