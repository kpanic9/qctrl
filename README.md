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

