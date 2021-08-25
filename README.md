# Deploying-ec2-instance-using-Terrfaorm-and-Hashipcorp-Vault

# What is Hashicorp Vault ?

HashiCorp Vault is a secrets management tool specifically designed to control access to sensitive credentials in a low-trust environment. It can be used to store sensitive values and at the same time dynamically generate access for specific services/applications on lease.

Here i am using Amazon linux 2 image to setup vault 
<p align="center">
  <img width="1000" height="100" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/ec2-instance.jpg?raw=true">
</p>
## Step 1: Download Vault
Precompiled Vault binaries are available for download at https://releases.hashicorp.com/vault/ and Vault Enterprise binaries are available for download by following the instructions made available to HashiCorp Vault customers.

You should perform checksum verification of the zip packages using the SHA256SUMS and SHA256SUMS.sig files available for the specific release version. HashiCorp provides a guide on checksum verification for precompiled binaries.

First, export environment variables to specify the Vault download base URL and preferred Vault version for convenience and concise commands.

```
export VAULT_URL="https://releases.hashicorp.com/vault" VAULT_VERSION="1.5.0"
```
Then use `curl` to download the package and SHA256 summary files.
```
curl \
    --silent \
    --remote-name \
   "${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
```
Use `curl` to download the package and SHA256 summary files.

```
curl \
    --silent \
    --remote-name \
    "${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS"
```
```
curl \
    --silent \
    --remote-name \
    "${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig"
```

You should now have the 3 files present locally:
```
ls -1
vault_1.5.0_SHA256SUMS
vault_1.5.0_SHA256SUMS.sig
vault_1.5.0_linux_amd64.zip
```

## Step 2: Install Vault

Unzip the downloaded package and move the `vault` binary to `/usr/local/bin/`.

```
unzip vault_${VAULT_VERSION}_linux_amd64.zip
```

Set the owner of the Vault binary.
```
sudo chown root:root vault
```
Check `vault` is available on the system path.
```
sudo mv vault /usr/local/bin/
```

You can verify the Vault version.
```
vault --version
```

The `vault` command features opt-in autocompletion for flags, subcommands, and arguments (where supported).
```
vault -autocomplete-install
```
Enable autocompletion.
```
complete -C /usr/local/bin/vault vault
```

Give Vault the ability to use the mlock syscall without running the process as root. The mlock syscall prevents memory from being swapped to disk.
```
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
```

Create a unique, non-privileged system user to run Vault.
```
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
```

## Step 3: Configure systemd

Systemd uses [documented reasonable defaults](https://www.freedesktop.org/software/systemd/man/systemd.directives.html) so only non-default values must be set in the configuration file.

Create a Vault service file at /etc/systemd/system/vault.service.

Add the below configuration to the Vault service file:

```
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target

```

## Start Web UI
Create server configuration file named config.hcl.

```
tee config.hcl <<EOF
ui = true
disable_mlock = true

storage "raft" {
  path    = "./vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
EOF
```

The raft storage backend requires the filesystem path `./vault/data`.

Although the listener stanza disables TLS (tls_disable = "true") for this tutorial, Vault should always be used with TLS in production to provide secure communication between clients and the Vault server. It requires a certificate file and key file on each Vault host.

Create the vault/data directory for the storage backend.
```
mkdir -p vault/data
```

Start a Vault server with server configuration file named `config.hcl`.
```
vault server -config=config.hcl
```
Example output:

```
WARNING! mlock is not supported on this system! An mlockall(2)-like syscall to
prevent memory from being swapped to disk is not supported on this system. For
better security, only run Vault on systems where this call is supported. If
you are running Vault in a Docker container, provide the IPC_LOCK cap to the
container.
==> Vault server configuration:

             Api Address: http://127.0.0.1:8200
                     Cgo: disabled
         Cluster Address: https://127.0.0.1:8201
              Go Version: go1.14.7
              Listener 1: tcp (addr: "0.0.0.0:8200", cluster address: "0.0.0.0:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: info
                   Mlock: supported: false, enabled: false
           Recovery Mode: false
                 Storage: raft (HA available)
                 Version: Vault v1.5.3
             Version Sha: 9fcd81405feb320390b9d71e15a691c3bc1daeef

==> Vault server started! Log data will stream in below:

2020-09-20T19:55:29.519-0700 [INFO]  proxy environment: http_proxy= https_proxy= no_proxy=
```

<p align="center">
  <img width="1000" height="400" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/vault%20running%20info.jpg?raw=true">
</p>

Launch a web browser, and enter `http://public_ip:8200/ui` in the address.

The Vault server is uninitialized and sealed. Before continuing, the server's storage backend requires starting a cluster or joining a cluster.

Select Create a new Raft cluster and click Next.

<p align="center">
  <img width="1000" height="400" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/vault%20webui.jpg?raw=true">
</p>
Enter `5` in the Key shares and `3` in the Key threshold text fields.

<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/initialize%20vault.jpg?raw=true">
</p>

Click `Initialize`.

When the unseal keys are presented, scroll down to the bottom and select Download key. Save the generated unseal keys file to your computer.

<p align="center">
  <img width="1000" height="500" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/download%20keys.jpg?raw=true">
</p>

The unseal process requires these keys and the access requires the root token.

Click Continue to Unseal to proceed.

Open the downloaded file.

Example key file:
```
{
  "keys": [
    "ecfb4ef59f9a2570f856c471cd3b0580e2b7d99962d5c9af7a25b80138affe935a",
    "807e9bbfb984c631becc526c621c9852f82d88b2347f7398ef7af3c1fbfbbe9fd0",
    "561a7ff6b44b88f96a2d9faca1ae514d1557008ce19283dcfe2fb746ed4f0f7d94",
    "3671e9e817177d79d3c004e0745e5f1d1a5cbfcd9fd6ad22505d4bc538176fa3f9",
    "313fffc1c848276fffe1e3fcfce4d3472d104cda466227ca155e4f693cfbaa36b9"
  ],
  "keys_base64": [
    "7PtO9Z+aJXD4VsRxzTsFgOK32Zli1cmveiW4ATiv/pNa",
    "gH6bv7mExjG+zFJsYhyYUvgtiLI0f3OY73rzwfv7vp/Q",
    "Vhp/9rRLiPlqLZ+soa5RTRVXAIzhkoPc/i+3Ru1PD32U",
    "NnHp6BcXfXnTwATgdF5fHRpcv82f1q0iUF1LxTgXb6P5",
    "MT//wchIJ2//4eP8/OTTRy0QTNpGYifKFV5PaTz7qja5"
  ],
  "root_token": "s.p3L38qZwmnHUgIHR1MBmACfd"
}
```
Copy one of the keys (not keys_base64) and enter it in the Master Key Portion field. Click Unseal to proceed.

<p align="center">
  <img width="1000" height="500" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/unsealing%20vault.jpg?raw=true">
</p>

<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/provided%202.jpg?raw=true">
</p>

The Unseal status shows 1/3 keys provided. Enter another key and click Unseal. The Unseal status shows 2/3 keys provided. Enter another key and click Unseal. After 3 out of 5 unseal keys are entered, Vault is unsealed and is ready to operate. Copy the root_token and enter its value in the Token field. `Click Sign in`.

<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/root%20token.jpg?raw=true">
</p>

## Web UI Wizard
Vault UI has a built-in tutorial to navigate you through the common steps to operate various Vault features.

<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/first%20screen.jpg?raw=true">
</p>

Now we have to launch the vault which will use aws access key and secret key. Using aws access key and secret key vault will dynamically create new access key and secret key for particular resources and this keys are valid for certain period of time.


```
---------------------vault.tf---------------------------
provider "vault" {
 address = "${var.vault_addr}"
 token = "${var.vault_token}"
}
resource "vault_aws_secret_backend" "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-east-2"
  default_lease_ttl_seconds = "120"
  max_lease_ttl_seconds     = "240"
}
resource "vault_aws_secret_backend_role" "ec2-admin" {
  backend = "${vault_aws_secret_backend.aws.path}"
  name    = "ec2-admin-role"
  credential_type = "iam_user"
policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*", "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
```

```
---------------------vault_variables.tf---------------------------
variable "vault_addr" {
 default = "http://public_ip:8200"
}
variable "vault_token" {
 default = "xxxxxxxxxxxxxxxxxxxxx"
}
variable "access_key" {
 default = "xxxxxxxxxxxxxxxxxxxxx"
}

variable "secret_key" {
 default = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}


```

## S3 Backend
Here i am using backend from s3. So as soona s terraform.tfstate file creates then it will automatically stores in s3 bucket.

<p align="center">
  <img width="1000" height="300" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/s3.jpg?raw=true">
</p>

<p align="center">
  <img width="1000" height="300" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/dev.jpg?raw=true">
</p>

<p align="center">
  <img width="1000" height="300" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/tfstate%20file.jpg?raw=true">
</p>

```
---------------------backend.tf---------------------------
terraform {
  backend "s3" {
    bucket = "terraformbackend1"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
}
```

## Terraform Init
<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/new%20all%20code.jpg?raw=true">
</p>

## Terraform Apply
<p align="center">
  <img width="1000" height="475" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/vault%20terrfaorm%20apply.jpg?raw=true">
</p>

After running terraform code successfully navigate to vaut dashboard. You will find that aws credentials automatically created with previous access and secret key.

<p align="center">
  <img width="1000" height="300" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/aws%20vault.jpg?raw=true">
</p>

Click to aws and you will find that you have created ec2-admin role as you can see below.

<p align="center">
  <img width="1000" height="300" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/ec2_admin_role.jpg?raw=true">
</p>

Now you can use this role to create your respective resources.
So now i will create an ec2 instance with below respective infra.
1. VPC
2. Subnets
3. Internet Gateway
4. Routing Table
5. Security Groups
6. Keypairs
7. Ec2 Instance

```
Note: After creating a aws vault then only you have to run the terrfaorm code for ec2 instance
```
The code for creating ec2 instance is mentioned above.

<p align="center">
  <img width="1000" height="450" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/ec2%20instance%20launch.jpg?raw=true">
</p>

<p align="center">
  <img width="1000" height="150" src="https://github.com/amit17133129/Deploying-ec2-instance-using-Terraform-and-Hashipcorp-Vault/blob/main/images/my%20terraform%20os.jpg?raw=true">
</p>

