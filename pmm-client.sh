#!/bin/bash


INTERACTIVE=YES
this=$( basename "$0" )

if [ ! -z "$HELP" ];
then
    echo "$this
Install, uninstall or upgrade PMM Client (pmm-admin).
Adjust settings in conf.sh. Settings are documented in that file.

Additional options can be passed as environment variables, for example in this way:
VAR=value $this

Options understood:

    HELP=1        Print this help and exit.
    ACTION        Allowed values: SHOW | INSTALL | REINSTALL | UNINSTALL
                  Case-insensitive.
                  Default: SHOW

Action modifiers:
    SKIP_ADD_USER=1      On INSTALL, don't run CREATE USER.
                         Any value (including 0) enables this option.
    FORCE_CREATE_USER=1  On INSTALL, DROP and reCREATE user if it exists.
                         Any value (including 0) enables this option.
    SKIP_DROP_USER=1     On UNINSTALL and REINSTALL, don't run DROP USER.
                         Any value (including 0) enables this option.
"
    exit 0
fi


LOG=log
date > $LOG

pretty_hostname=$( hostname | cut -d'.' -f1 )
echo "Prettified hostname: $pretty_hostname" >> $LOG

source conf.sh
specific_conf_file=hosts/$pretty_hostname
if [ -f $specific_conf_file ];
then
    echo "Trying to include $specific_conf_file" >> $LOG
    source $specific_conf_file
else
    echo "Specific configuration file not found: $specific_conf_file" >> $LOG
fi


#  Functions
#  =========

log () {
    message=$1
    echo $message >> $LOG
}

abort () {
    exit_code=$1
    message=$2
    message1="[ERROR] $message"
    message2='ABORT'
    log "$message1"
    echo $message1
    log "$message2"
    echo $message2
    exit $exit_code
}

success () {
    message=$1
    echo $message
    exit 0
}

run () {
    command=$1
    ignore_errors=$2

    if [ "$FORCE_SUDO" == '1' ];
    then
        command="sudo $command"
    fi

    echo "Running command: $command" >> $LOG
    $command > tmp-stdout 2> tmp-stderr
    r=$?

    stderr=$( cat tmp-stderr )
    stdout=$( cat tmp-stdout )
    echo 'STDOUT:' >> $LOG
    cat tmp-stdout >> $LOG
    echo 'STDERR:' >> $LOG
    cat tmp-stderr >> $LOG
    log "EXIT CODE: $r"

    if [ ! -z "$stderr" ];
    then
        echo "$stderr"
    fi

    rm -f tmp-std*

    if [ "$ignore_errors" != '1' ] && [ "$r" != '0' ];
    then
        abort $r "Last command failed with exit code: $r"
    fi
}


#  Defaults
#  ========

if [ -z "$ACTION" ];
then
    ACTION='SHOW'
else
    ACTION=${ACTION^^}
    if [ $ACTION != 'SHOW' ] && [ $ACTION != 'INSTALL' ] && [ $ACTION != 'UNINSTALL' ] && [ $ACTION != 'REINSTALL' ];
    then
        abort 2 "Invalid action: $ACTION"
    fi
fi

if [ -z "$FORCE_SUDO" ] || [ "$FORCE_SUDO" != '1' ];
then
    FORCE_SUDO='0'
fi

if [ -z "$PMM_SERVER_HOST" ];
then
    PMM_SERVER_HOST=$( cat info/pmm-server-host )
fi

# User to DROP / CREATE PMM Client user in MariaDB
account="'$PMM_CLIENT_MARIADB_USER'@'$PMM_CLIENT_MARIADB_HOST'"
account_was_dropped=0


#  Validation
#  ==========

if [[ $(id -u) -gt 0 ]];
then
    if [ "$FORCE_SUDO" == '0' ];
    then
        abort 2 "$this needs to run as root, with sudo, or with FORCE_SUDO=1"
    fi
fi


#  Body
#  ====

log "ACTION: $ACTION"

# on SHOW, show information and exit
pmm_admin=$( which pmm-admin 2> /dev/null )
if [ $ACTION == 'SHOW' ];
then
    if [ ! -z "$pmm_admin" ];
    then
        pmm-admin status
        pmm-admin list
    else
        echo 'PMM2 Client is not installed'
    fi
    success ''
fi

# on UNINSTALL, uninstall pmm2-client if it's installed and exit
if [ $ACTION == 'UNINSTALL' ];
then
    if [ -z "$SKIP_DROP_USER" ];
    then
        sql="mysql -e \"DROP USER IF EXISTS $account\""
        run "$sql"
        account_was_dropped=1
    fi

    if [ ! -z "$pmm_admin" ];
    then
        log "pmm-admin found: $pmm_admin"
        run "yum remove -y pmm2-client"
        success 'PMM Client successfully uninstalled'
    else
        log 'PMM2 Client is not installed'
        success 'PMM2 Client is not installed'
    fi
fi

# on REINSTALL, uninstall pmm2-client if it's installed and continue
if [ $ACTION == 'REINSTALL' ];
then
    if [ -z "$SKIP_DROP_USER" ];
    then
        sql="mysql -e \"DROP USER IF EXISTS $account\""
        run "$sql"
        account_was_dropped=1
    fi

    if [ ! -z "$pmm_admin" ];
    then
        log "pmm-admin found: $pmm_admin"
        run 'yum remove -y pmm2-client'
        echo 'PMM Client successfully uninstalled'
        # wait 1 second, in case yum is still holding a lock
        # because we're using it again
        sleep 1
    else
        log 'PMM2 Client is not installed'
        echo 'PMM2 Client is not installed'
    fi
fi

# At this point, ACTION may be:
#   - REINSTALL: The uninstall part is done, continue to install again
#   - INSTALL: Continue to install

if [ -z "$SKIP_CREATE_USER" ];
then
    if [ -z "$FORCE_CREATE_USER" ];
    then
        sql="mysql -e \"DROP USER IF EXISTS $account\""
        run "$sql"
    fi
    sql="mysql -e \"CREATE USER IF NOT EXISTS $account IDENTIFIED BY PASSWORD 'PMM_CLIENT_MARIADB_PASSWORD' WITH MAX_USER_CONNECTIONS 10;\""
    run "$sql"
    sql="GRANT SELECT, PROCESS, SUPER, REPLICATION CLIENT, RELOAD ON *.* TO $account;"
    run "$sql"
fi

# if Percona repositories are already installed,
# we need to disable and re-enable them as documented by Percona
percona_release=$( which percona-release 2> /dev/null )
if [ ! -z "$percona_release" ];
then
    run "percona-release disable all"
    run "percona-release enable original release"
fi

# add repository and install pmm2-client
run "yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm" '1'
run "yum install -y pmm2-client"

# register the node to PMM Server
# we use --force to avoid checking the return code in case of failures
run "pmm-admin config --force --server-insecure-tls --server-url=https://$PMM_SERVER_USER:$PMM_SERVER_PASSWORD@$PMM_SERVER_HOST:443"

# add requested service(s)
if [ $PMM_SERVICE_MYSQL == '1' ];
then
    run "pmm-admin add mysql $PMM_CLIENT_MARIADB_HOST:$PMM_CLIENT_MARIADB_PORT --username=$PMM_CLIENT_MARIADB_USER --password=$PMM_CLIENT_MARIADB_PASSWORD --query-source=$PMM_CLIENT_MARIADB_QUERY_SOURCE --disable-queryexamples --service-name=$pretty_hostname --environment=$PMM_SERVICE_MARIADB_ENVIRONMENT --cluster=$PMM_SERVICE_MARIADB_CLUSTER"
fi

success 'SUCCESS'


# TODO:
#   - Allow to install a specific version of pmm2-client
#   - The INSTALL and REINSTALL actions should continue if a component is already in place
#   - Allow to use a non-standard server port

