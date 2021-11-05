#!/bin/bash


INTERACTIVE=YES
this=$( basename "$0" )

if [ ! -z "$HELP" ];
then
    echo "$this
Install, uninstall or upgrade Prometheus AlertManager.
Adjust settings in conf.sh. Settings are documented in that file.

Additional options can be passed as environment variables, for example in this way:
VAR=value $this

Options understood:

    HELP=1       Print this help and exit.
    ACTION       Allowed values: STATUS | INSTALL | REINSTALL | UNINSTALL
                 Case-insensitive.
                 Default: STATUS
"
    exit 0
fi


LOG=log
date > $LOG

source conf.sh


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

run () {
    command=$1
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

    if [ "$r" != '0' ];
    then
        abort "$r" "Last command failed with exit code: $r"
    fi
}


#  Defaults
#  ========

if [ -z "$ACTION" ];
then
    ACTION='STATUS'
else
    ACTION=${ACTION^^}
    if [ $ACTION != 'STATUS' ] && [ $ACTION != 'INSTALL' ] && [ $ACTION != 'REINSTALL' ] && [ $ACTION != 'UNINSTALL' ];
    then
        abort '2' "Invalid action: $ACTION"
    fi
fi


#  Validation
#  ==========

# Nothing to validate at present.


#  Body
#  ====

log "ACTION: $ACTION"
mkdir info 2> /dev/null
run "kubectl config set-context --current --namespace=$PMM_SERVER_NAMESPACE"


if [ $ACTION == 'STATUS' ];
then
    # show info and exit
    kubectl get services alertmanager
    exit 0
elif [ $ACTION == 'UNINSTALL' ];
then
    # uninstall and exit
    run "helm delete alertmanager"
    exit 0
elif [ $ACTION == 'REINSTALL' ];
then
    # uninstall and then continue
    run "helm delete alertmanager"
fi


# We're here if ACTION=INSTALL or ACTION=REINSTALL

run "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
run "helm repo update"
run "helm install alertmanager prometheus-community/alertmanager"

