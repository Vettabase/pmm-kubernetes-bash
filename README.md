# pmm-kubernetes-bash

Bash scripts to manage PMM Server and Clients.

This project is meant for cases where frameworks like Ansible or Puppet
are not desirable for some reason, or not necessary.


## Configuration

Copy the configuration template:

```
cp conf.sh.default.sh conf.sh
```

`conf.sh` contains all the configuration. Each option is documented in the file itself.

The file is ignored by git.


## Usage

Currently scripts usage is documented in the scripts themselves.
To see their built-in help:

```
HELP=1 ./pmm-server.sh
HELP=1 ./pmm-client.sh
```

`ACTION=INSTALL pmm-server.sh`  outputs, amongst other things, the IP of PMM Server.
But you may need this information at any later time. To obtain it, run:

```
./get-ip.sh
```

It only outputs the IP, so it can be piped to another script.


## Copyright and License

Copyright  2021  Vettabase Ltd

License: BSD 3 (BSD-New).

Developed and maintained by Vettabase Ltd:

https://vettabase.com

Contributions are welcome.
