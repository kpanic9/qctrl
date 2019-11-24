# Q-CTRL Chanllenge   
    
   
## Deploying   
     
```bash
git clone {repo}
cd q-ctrl/

# setup aws credentials
export AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

terraform init
# list infra changes
terraform plan -out qctrl.plan
# deploy resources
terraform apply qctrl.plan
```    
    
   
## Destroy    
     
```bash
terraform destroy
```   
   

## TODO    
    
1. Properly tag the resources
2. Configure scaling policies for adapting to the load
3. Writing the terraform code in a reusable modular manner by braking down into modules like network, sg, application at least
4. Setup a dns name for web site
5. Configure a ssl certificate
6. Enable log collection and monitoring through CloudWatch
7. Setup remote backend for storing terraform state
8. Use a different repo for web site and setup CI/CD for deployments
      
