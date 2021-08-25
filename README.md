# Deploying-ec2-instance-using-Terrfaorm-and-Hashipcorp-Vault

# What is Hashicorp Vault ?

HashiCorp Vault is a secrets management tool specifically designed to control access to sensitive credentials in a low-trust environment. It can be used to store sensitive values and at the same time dynamically generate access for specific services/applications on lease.

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

