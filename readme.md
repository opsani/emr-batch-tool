# Opsani AWS Elastic MapReduce Batch Job Readme

## System Overview
Opsani helps you get your work done, better. You have plenty of work to do on remote compute clusters. As a developer, there are a myriad of settings to tinker with that might help you in your quest to optimize the work you are doing. Unfortunately, the sheer number of options makes manual optimization an intractable problem if you want to do anything else productive with your time. Even with a relatively small problem space, knowing how many nodes to use in a cluster, or what the size of those nodes needs to be in order to achieve high performance at the right price can be a full-time job. Worse yet, the "ideal" setting can change depending on the way your write your programs and the type of data you are processing.

Cue the *Opsani Continous Optimization Engine* (OCO). The OCO is simple to explain, but powerful when applied to your clusters, your applications, and your ever evolving data.
1. First, you **do the work**. In this context, this is running your Jupyter notebook.
2. Next, the OCO **measures** that work and records the result.
3. Then, the OCO **makes changes** and runs the work again.
4. Finally, the OCO **repeats** that process until it converges on an ideal setting to process your data in a performant and cost-effective way. 

When your application or your data changes, the OCO kicks in to repeat the process and make sure you are staying in that sweet spot of high performace for cost.

This document focuses on helping you to begin that journey by structuring your batch jobs in Amazon Elastic MapReduce (EMR) so that they can be run automatically with different infrastructure settings. When you are done working with this document and associated scripts, you will be ready for an Opsani engineer to help you connect your jobs directly to Opsani's powerful Continuous Optimization engine and leave infrastructure optimization guesswork behind forever.

This document will introduce you to a few tasks that you will need to perform to take advantagage of the OCO. The associated scripts are all open and you can modify them as you see fit to run inside of your infrastructure. The work is yours. The applications are yours. The data is yours. None of this will ever reach Opsani. The only things exchanged between Opsani and your servers will be performance telemetry and suggested settings for optimization. You have full control.

In particular, the associated scripts will run inside of your AWS account. You should test and run these scripts within an environment that has the appropriate credentials to modify S3 buckets (or another location that holds your data and Jupyter notebooks) *and* has permissions to work with AWS Elastic MapReduce.

After you are done, Opsani engineers will help you take your script and put it into a Servo that will run inside of your organization. This Servo trigger the work you have (or will) specify, measure the performance, and make changes to the infrastructure to help find the ideal settting for your infrastructure. The Servo acts as a loyal servant, helping the OCO fully explore the problem space in the quest for the most optimal setttings for your data and application.

## How to Use

*Doing the work* involves three stages:
1. Prepare
2. Launch and Run
3. Clean Up

### Prepare 

The purpose of the prepare stage is to do all of the pre-work for you to be able to run one of your Jupyter notebooks. This includes making your Jupyter notebooks accessible to the script. This includes loading any data or other information you need into a place that is accessible to these scripts. For example, this might mean placing a representative sample of your data in an accessible S3 bucket. Remember, the script runs in the context of your AWS account. At no point will Opsani or the OCO need your AWS credentials.

### Launch and Run

During the Launch and Run phase, the script will create a cluster and run your notebooks. This is the meat of the script. You should be able to run this script on your own after completing this phase. By default, the script will create a cluster using your AWS credentials. (If you are giving it a test drive and stop at this point, you will need to be sure to manually remove the cluster from the AWS console or using the AWS CLI.) You should be able to use the console to check and make sure that the cluster is running your steps.

### Clean Up

When the Jupyter notebooks have completed their run, the script will tear down the cluster and reset the environment so that we can perform another run wth different settings. You will want to try to reset the data to its original state. This allows us to use the data as a control variable. At the end of this step, we need to be prepared to run things again with the same data, but different settings. 

## How We Will Use This

After you complete this script, Opsani engineers will help you embed it in an Opsani-provided Servo. That Servo will feed information back into Opsani's Continuous Optimization Engine (OCO). The OCO will will then provide you with more ideal settings to run your jobs.

Note: If the nature of the data changes we can and should run this process again. As long as the steps to run the notebooks for new data remain consistent, changes to the work being done in your Jupiter notebook or to the data itself should not change the tooling significantly. Changing data or the application may change the optimal settings for your work. We can automatically run this again for different cirumstances. This is the power of continuous optimization.

## Next Steps

Look through the script in this repository and modify it so that it can run inside of your own infrastructure. Make changes where appropriate to ensure that your data and notebooks are accessible to the script. This may require changing some of the settings in the script such as the AWS region, or where the script pulls data from. This script depends upon valid AWS credentials in your environment. If you can run this script inside of your environment, perhaps in an EC2 instance, then you should be good to go. At that point, we should be able to add it to a Servo that will help measure peformance and make adjustments. 

Once you've completed this stage, please contact us and we can help you get going.