# pmm-kubernetes-bash

Bash scripts to manage PMM Server and Clients.

This project is meant for cases where frameworks like Ansible or Puppet
are not desirable for some reason, or not necessary.


## Configuration

Copy the configuration template:

```bash
cp conf.sh.default.sh conf.sh
```

Also copy the example 'values' file:

```bash
cp example-values.yaml values.yaml
```

`conf.sh` and `values.yaml` contain all the configuration. Each option is
documented in the files themselves.

NB! Make sure the values are the same for `PMM_SERVER_PASSWORD` in `conf.sh` and
`pmm_password` in `values.yaml`.

These file are ignored by git.

### Notes about the values.yaml file

The `example-values.yaml` file has the `service` `type` as `ClusterIP`, so it
can use the separate `LoadBalancer` (see below).

Note also that the `storageClassName` used is a magical one which in the
Diamond Kubernetes cluster will give us node-local storage.

## Usage

Currently scripts usage is documented in the scripts themselves.
To see their built-in help:

```bash
HELP=1 ./pmm-server.sh
HELP=1 ./pmm-client.sh
```

`ACTION=INSTALL pmm-server.sh`  outputs, amongst other things, the IP of PMM Server.
But you may need this information at any later time. To obtain it, run:

```bash
./get-ip.sh
```

It only outputs the IP, so it can be piped to another script.

## Load balancer

Currently, the project needs a separate LoadBalancer to work. This has a fixed
IP address which was assigned especially for PMM.

Install this with:

```bash
kubectl apply -f ./pmm-loadbalancer.yaml
```

## Copyright and License

Copyright  2021  Vettabase Ltd

License: BSD 3 (BSD-New).

Developed and maintained by Vettabase Ltd:

https://vettabase.com

Contributions are welcome.
