# Deploying Batch Job Continuous Optimization in Your Organization

## Purpose

The purpose of this guide is to provide you with everything you need to successfully deploy the Opsani Continuous Optimization (OCO) Servo inside of your AWS account. This guide will walk you through the following steps:

First, you will be creating a Docker virtual machine to host the continuous optimization servo. 

Second, you will install the Opsani Continuous Optimization (OCO) Servo on the Docker virtual machine. 

Third, you will launch your Jupyter notebook payload on an AWS Elastic Map Reduce Cluster using your work script.

The end result of this will be that you have all of the infrastructure you need within your organization to be able to optimize batch processes for AWS Elastic Map Reduce through the Opsani Continuous Optimization (OCO) system. This infrastructure can be extended to optimize other applications and services.

## Step 1: Create a Docker virtual machine to host the Opsani Continuous Optimization (OCO) Servo

We want to make this as easy as possible for you. Because you are using Amazon Web services, we can provide you with a template for Amazon cloud formation. This will allow you to instantiate an EC2 server from a template.

(N.B.: The position and wording of some elements may be different depending on whether or not you are using the New EC2 Experience layout in AWS.)

1. Log in to AWS.
1. Ensure that you have the template file named `ec2-docker-python3-amazon-linux-2.cft` provided to you by Opsani.
2. Go to the [AWS Cloud Formation](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/) webpage and click the "Create" button. (You may wish to change the region.)
3. On the _Create Stack_ page, under the _Prerequisites_ section make sure that "Template is Ready" is selected. Under the _Specify Template_ section, choose "Upload a template file" and upload `ec2-docker-python3-amazon-linux-2.cft`. Choose "Next".
4. Give your stack a name, and choose the t2.small instance size. Choose an EC2 key pair to use to connect to this instance. (_If you do not have one, you will need to go to the EC2 settings so that you can upload a private key or generate a new key for this instance._) Choose next.
5. On the "Configure Stack Options" page, click the orange "Next" button at the bottom.
6. On the "Review" page, choose the orange "Create Stack" button at the bottom.
7. Wait until the servo instance switches from "CREATE_IN_PROGRESS" to "CREATE_COMPLETE", then click on the _Resources_ tab at the top. (You may need to refresh the list using the "Reload" icon on the right side, or by refreshing the page.)
8. You will see a list of stacks in your Cloud Formation on the left-hand side of the browser window. Make sure that the stack you have just created is chosen and is in the "CREATE_COMPLETE" status. On the right side under _Resources_ click on the physical ID of the servo instance you have created. This link will take you to the EC2 Instances page, searching directly for that physical ID.
9. Choose _Connect_ for the given instance and follow the instructions on the connect panel to connect through SSH. You will need the private key you chose above.

At this point you should have shell access using the `ec2-user`. You are now ready to initially install the Opsani Continuous Optimization (OCO) Servo and give it a test.

## Step 2: Install the Opsani Continuous Optimization (OCO) Servo

In this step we will do little to no customization on the Servo, but instead will ensure that it works and can connect to the Opsani API.

First we will install additional dependencies needed to boostrap the Servo. Then we will use Docker to install and run the Servo. The Docker install has a number of dependencies, including credentials you need to obtain from the [Opsani Console](https://console.opsani.com/). Please verify that you have access to the Console.

(N.B. Opsani does not currently send an invitation email. Please simply try logging in.)

### Installing Docker-Compose

The virtual machine we are using comes with Docker, but it does not come with Docker compose. Install this now with the following commands:

```
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Verify that Docker compose is installed and in the path by running `docker-compose --version`.

### Create the Servo Dockerfile

```
mkdir opsani
cd opsani

cat > Dockerfile <<EOF
FROM python:3.6-slim-stretch

WORKDIR /servo

# Install python3 dependencies
RUN pip3 install PyYAML boto3 requests

# Install servo and servo-batch plugin
ADD https://raw.githubusercontent.com/opsani/servo/master/servo \
	https://raw.githubusercontent.com/opsani/servo/master/adjust.py \
	https://raw.githubusercontent.com/opsani/servo/master/measure.py \
	https://raw.githubusercontent.com/opsani/servo/master/state_store.py \
	https://raw.githubusercontent.com/opsani/servo-batch/master/common.py \
	https://raw.githubusercontent.com/opsani/servo-batch/master/adjust \
	https://raw.githubusercontent.com/opsani/servo-batch/master/measure \
	/servo/

# Add job command and any additional files
ADD run_job.sh \
	/servo/

RUN cd /servo && \
	chmod a+x adjust measure servo run_job.sh

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "python3", "servo" ]
EOF
```

### Get the Opsani Token and Other credentials

Log in to your app in the console: https://console.opsani.com/accounts/komodohealth.com

On the menu on the left side, you will see "Servo". Choose "Servo" under the application you are working with. You will see a "Servo Setup Instructions" page. Select "Download Servo Artifacts for [APPLICATION NAME]".

You will receive a compressed file. Decompress the file and open `install.sh` in your favorite text editor to get the values for ACCOUNT, APP_ID, and OPTUNE_AUTH_TOKEN.

The OPTUNE_AUTH_TOKEN needs to be in a file titled `optune.token` in the working directory.

ACCOUNT and APP_ID need to be placed in a file named `.env`, and named `ACCOUNT_ID` and `APP_ID` respectively.

❗️❗️❗️Question for Robert. Should I not source the .env . . . and see below.
For good measure `source .env`.

### Create the Docker Compose file

With credentials in place, we can now create a Docker Compose file.

```
cat > docker-compose.yaml <<EOF
version: '3.4'
services:
  opsani-servo:
    network_mode: host # Optional
    build:
      network: host # Optional
      context: .
    restart: always
    volumes:
      - type: bind
        source: ./config.yaml
        target: /servo/config.yaml
        read_only: true
      - type: bind
        source: ./optune.token
        target: /run/secrets/optune_auth_token
        read_only: true
    command: --account ${ACCOUNT_ID} ${APP_ID}
EOF
```
❗️❗️❗️ And should I be putting \{ \} in the command line above so the cat < ZZZ <<EOF thing doesn't mess with variable substitutions immediately?


### Create the barebones config.yaml file

Use the following command to create a barebones config.yaml file that we will later customize.

```
cat > config.yaml <<EOF
batch:
  # Command to run (required)
  command: ./run_job.sh --MasterType={master.inst_type} --WorkerType= {worker.inst_type} --nWorkers={worker.replicas:.0f} --GCType= {worker.gc_type} --InputData=dataset.csv

  # Default state to use when no previous adjust (required)
  application:
    components:
      master:
        settings:
          inst_type:
            type: enum
            unit: ec2
            default: m5.xlarge
            values:
            - m5.xlarge
            - m5.2xlarge
            - c5.xlarge
            - c5.2xlarge
      worker:
        settings:
          inst_type:
            type: enum
            unit: ec2
            default: m5.xlarge
            values:
            - m5.xlarge
            - m5.2xlarge
            - c5.xlarge
            - c5.2xlarge
          replicas:
            type: range
            min: 1
            max: 50
            step: 1
            default: 32
          gc_type:
            type: enum
            default: G1GC
            values:
            - G1GC
            - ParNewGC
            - ParallelOldGC
            - ConcMarkSweepGC

  metrics:
    job_duration:
      # NOTE: Do not use double quotes as it will cause the yaml load to interpret the backslashes meant for regex as escape sequences
      output_regex: 'Job completed in ([\.\d]+) seconds'
      unit: seconds
    n_records:
      # NOTE: Do not use double quotes as it will cause the yaml load to interpret the backslashes meant for regex as escape sequences
      output_regex: 'Processed ([\.\d]+) records'


  expected_duration: 7200 # seconds; used for progress estimation
EOF
```

### Create the workload

We have also referenced a `run_job.sh` script above. This file needs to exist, and is the file that will build your cluster, run your work, take measurements, and tear down your cluster afterwards.

For the time being, we will use an empty script: 

```
cat > run_job.sh <<EOF
#!/bin/bash
echo "Job will go here."
EOF
chmod +x run_job.sh
```

### Testing the Servo

We are now ready to test the Servo to see if it is communicating with the Opsani API.

Use `docker-compose build` and `docker-compose up -d` to start the Servo. If all goes well, you should get no errors or warnings. 

Run `docker-compose logs` to ensure that we are communicating with Opsani. At this point you _should_ get an error, and the error should say: ` Exception: No match found in batch standard output for metric name 'job_duration'.` This is expected, because we aren't really running your job yet, and we aren't reporting back the duration.

## Step 3: Customizing the Job, or How to Launch your Jupyter notebook payload on an AWS Elastic Map Reduce Cluster using your work script.

For the time being, please refer to https://github.com/opsani/emr-batch-tool