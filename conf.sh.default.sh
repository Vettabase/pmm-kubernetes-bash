#!/bin/bash


# Configuration for PMM Server-related scripts.


# If set to 1, commands that require root privileges will be run with sudo
FORCE_SUDO=1

# Namespace/context for PMM-Server pods
PMM_SERVER_NAMESPACE='...'
# Platform option
PMM_SERVER_PLATFORM=kubernetes
# Used by the PMM Clients to communicate with the server.
# It can be specified by writing the hostname into info/pmm-server-host.
PMM_SERVER_HOST=
# User to connect PMM Server.
# Currently changing this is not supported because of a bug in Percona operator.
# Until the bug is solved, PMM_SERVER_USERS should be 'admin'.
PMM_SERVER_USER='admin'
# Password for PMM Server user
PMM_SERVER_PASSWORD='...'

# Set exactly to 1 to enable "mysql" service in PMM Client
PMM_SERVICE_MYSQL=1
# MariaDB host the client should connect to, in order to collect metrics
PMM_CLIENT_MARIADB_HOST='127.0.0.1'
# MariaDB port
PMM_CLIENT_MARIADB_PORT='3306'
# PMM Client username in MariaDB
PMM_CLIENT_MARIADB_USER='pmm-client'
# Password for PMM Client MariaDB account
PMM_CLIENT_MARIADB_PASSWORD='...'
# Allowed valued: none, perfschema, slowlog
PMM_CLIENT_MARIADB_QUERY_SOURCE=perfschema

# The following settings are used in the PMM user interface to filter hosts,
# so they should probably be defined at a host level.
# Don't make them empty though.
PMM_SERVICE_MARIADB_ENVIRONMENT=default
PMM_SERVICE_MARIADB_CLUSTER=default
PMM_SERVICE_MARIADB_REPLICA_SET=default
