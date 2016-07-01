# Azure Provisioning for GPDB

These Azure deployment templates allow near push-button install of Pivotal Greenplum Database on multiple Azure VMs.

### Login to Azure and set mode to ARM
```
$ azure login
$ azure config mode arm
```

### Checkout repo to a local directory
```
$ git clone git@github.com:kdunn926/azureDeploy.git
```

### Configure azuredeploy.parameters.json
##### (Note: any parameter listed in the ```parameters``` section of ```azuredeploy.json``` can be added to this file to override the defaults.)
- Public and private keypair data
- gpadmin default password
- Pivotal Network API key
- Cluster name
- Deployment Region
- Deployment/VM type
  - Use ```nicbonding``` for Standard_A10/11 (up to 15 data disks per server, hardcoded for 12)
  - Use ```8nicbonding``` for Standard_DS14_v2 or Standard_GS4/5 (up to 16 or 32 data disks per server)
- Number of masters (1 or 2)
- Number of segment servers
- Segment disk size (default 500GB)

### Create Resource Group

##### Example resource group in EastUS
```
$ azure group create gpdb-east -l eastus
```

### Deploy

##### Example cluster deployment
```
$ azure group deployment create -f azuredeploy.json -e azuredeploy.parameters.json gpdb-east -n gpdb-prod
```

### Login
```
$ ssh -i /path/to/my/sshPrivateKeyFile gpadmin@east-gpdb-mdw.eastus.cloudapp.azure.com
```

