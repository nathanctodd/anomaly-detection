
# Results - DS 5220: Data Project 1 
#### Nathan Todd


## Questions:
1. Technical Challenges Describe the greatest challenge(s) you encountered in translating the template from CloudFormation to Terraform. (1-2 paragraphs)
    - The greatest challenge I encountered was connecting all the various parts once I had pushed them all up using terraform. For example, the SNS topic had gotten pushed up properly, but hadn't been confirmed yet. It wasn't obvious to me at the time, however. This meant that I had to systematically try to find the issue by following the chain. I started by kicking off the test data generation and ensured it made it to the bucket, then went to the SNS topic to see if it was triggering properly. That is where I discovered it hadn't been confirmed yet, so after confirming I reran the script and saw files go all the way through and be processed. 

        While it wasn't anything insane, it taught me that there can be a lot of small issues that might make a system break, and so its important to either account for all of that in the terraform code before pushing it up, or understand the flow completely to know where to find the issue. 

2. Access Permissions What element (specify file and line #) grants the SNS subscription permission to send messages to your API? Locate and explain your answer.
    - At main.tf:38, we give the SNS topic permission to hit the endpoint, and at main.tf:183 we specify the endpoint that it should hit. We create the SNS topic policy and then give specific parameters about it to allow it to properly hit the endpoint.


3. Event flow and reliability: Trace the path of a single CSV file from the moment it is uploaded to raw/ in S3 until the FastAPI app processes it. What happens if the EC2 instance is down or the /notify endpoint returns an error? How does SNS behave (e.g., retries, dead-letter behavior), and what would you change if this needed to be production-grade?

    - The raw/ folder is tracked - if a .csv file hits the raw/ folder, then the SNS topic triggers and passes the CSV file through to the endpoint of our EC2 instance. The EC2 instance then processes the file and outputs the results to the processed/ folder, updating the state and logs along the way. If the EC2 instance is down, then the SNS topic will retry for a while and then eventually give up. If the /notify endpoint returns an error, then the SNS topic will also retry for a while and then give up. If this needed to be production-grade, I would set up a dead-letter queue for the SNS topic so that if it fails to process the message after a certain number of retries, it would send the message to the dead-letter queue for later analysis and reprocessing. This would help ensure that no messages are lost and that we can investigate any issues that arise in the processing of the messages. 


4. IAM and least privilege: The IAM policy for the EC2 instance grants full access to one S3 bucket. List the specific S3 operations the application actually performs (e.g., GetObject, PutObject, ListBucket). Could you replace the “full access” policy with a minimal set of permissions that still allows the app to work? What would that policy look like?

    - The application performs a GetObject operation to read the CSV files from the raw/ folder, and a PutObject operation to write the processed files to the processed/ folder. It never really lists the bucket or deletes anything, so we would want to only give the EC2 instance permissions to perform GetObject and PutObject operations on the specific bucket and folders it needs to access to adhere to the principle of least privilege. The policy would look something like this:

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject"
                ],
                "Resource": [
                    "arn:aws:s3:::ygu6ax-anomaly-detection/raw/*",
                    "arn:aws:s3:::ygu6ax-anomaly-detection/processed/*"
                ]
            }
        ]
    }
    ```

5. Architecture and scaling: This solution uses batch-file events (S3 + SNS) to drive processing, with a rolling statistical baseline in memory and in S3. How would the design change if you needed to handle 100x more CSV files per hour, or if multiple EC2 instances were processing files from the same bucket? Address consistency of the shared baseline.json, concurrent processing, and any tradeoffs.

    - If we needed to handle 100x more CSV files per hour, we would likely need to move away from using EC2 instances and instead use a more scalable solution like AWS Lambda or AWS Fargate. This would allow us to automatically scale up the number of instances processing the files as needed without having to manage the infrastructure ourselves. 

    If multiple EC2 instances were processing files from the same bucket, we would need to ensure that they are all using the same baseline.json file and that they are not overwriting each other's changes. One way to do this would be to use a distributed locking mechanism, such as DynamoDB or Redis, to ensure that only one instance is updating the baseline.json file at a time. Alternatively, we could use a versioning system for the baseline.json file and have each instance read the latest version before processing a file and then write back any updates with a new version number. 

    The tradeoffs of these approaches include increased complexity in managing the distributed locking or versioning system, as well as potential performance issues if there are a large number of instances trying to access the baseline.json file at the same time. However, these approaches would allow us to maintain consistency of the shared baseline while still allowing for concurrent processing of files.


## Appendix: Test Data Generation

Output from test data script:

(venv) ubuntu@ip-172-31-73-116:/anomaly-detection$ python test_producer.py 
Producing batches every 60s. Ctrl+C to stop.
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222150.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222250.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222350.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222450.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222550.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222650.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222750.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222850.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T222950.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223051.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223151.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223251.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223351.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223451.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223551.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223651.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223751.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223851.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T223951.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224052.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224152.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224252.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224352.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224452.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224552.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224652.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224752.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224852.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T224952.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225052.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225153.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225253.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225353.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225453.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225553.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225653.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225753.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225853.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T225953.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230053.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230153.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230253.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230354.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230454.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230554.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230654.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230754.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230854.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T230954.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231054.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231154.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231254.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231354.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231455.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231555.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231655.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231755.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231855.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T231955.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T232055.csv
Uploaded 100 rows → s3://ygu6ax-anomaly-detection/raw/sensors_20260304T232155.csv