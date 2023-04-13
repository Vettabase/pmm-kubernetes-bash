#!/bin/bash


INTERACTIVE=YES
this=$( basename "$0" )

if [ ! -z "$HELP" ];
then
    echo "$this
Install, uninstall or upgrade PMM Server.
Adjust settings in conf.sh. Settings are documented in that file.

Additional options can be passed as environment variables, for example in this way:
VAR=value $this

Options understood:

    HELP=1      Print this help and exit.
    ACTION      Allowed values: SHOW | INSTALL | UNINSTALL | REINSTALL.
                Case-insensitive.
                Default: SHOW.
    VERSION     The chart version to use.
                Default: latest
    WHAT        With ACTION = SHOW:
                    Allowed values: ALL | SYSTEM | SERVICES | VOLUMES | EVENTS
                    Default: ALL
                With ACTION = INSTALL | UNINSTALL | REINSTALL:
                    Allowed values: ALL | RELEASE | REPO | REPOSITORY
                    Default: RELEASE
                Case-insensitive.

INSTALL installs PMM Server, UNINSTALL removes it.
But default they install/remove everything, but you can specify WHAT to
only install/remove the repository or the release.

REINSTALL by default reinstalls the release only.
Specify REPO to remove the repository or ALL to remove both.

SHOW shows information about PMM if installed.
One can specify multiple comma-separated flags, for example:
ACTION=SHOW WHAT=SYSTEM,SERVICES ./pmm-server.sh
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

success () {
    message=$1
    echo $message
    exit 0
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
    ACTION='SHOW'
else
    ACTION=${ACTION^^}
    if [ $ACTION != 'SHOW' ] && [ $ACTION != 'INSTALL' ] && [ $ACTION != 'REINSTALL' ] && [ $ACTION != 'UNINSTALL' ];
    then
        abort '2' "Invalid action: $ACTION"
    fi
fi

if [ ! -z "$WHAT" ];
then
    WHAT=${WHAT^^}
else
    if [ $ACTION == 'REINSTALL' ];
    then
        WHAT='RELEASE'
    else
        WHAT='ALL'
    fi
fi


#  Validation
#  ==========

if [ $ACTION == 'INSTALL' ] || [ $ACTION == 'UNINSTALL' ] || [ $ACTION == 'REINSTALL' ];
then
    if [ $WHAT != 'ALL' ] && [ $WHAT != 'RELEASE' ] && [ $WHAT != 'REPO' ] && [ $WHAT != 'REPOSITORY' ];
    then
        abort '2' "Invalid object: $WHAT"
    fi
fi

if [ -z "$PMM_SERVER_NAMESPACE" ];
then
    abort '1' 'Empty variable: PMM_SERVER_NAMESPACE'
fi

if [ -z "$PMM_SERVER_PLATFORM" ];
then
    abort '1' 'Empty variable: PMM_SERVER_PLATFORM'
fi

if [ -z "$PMM_SERVER_USER" ];
then
    abort '1' 'Empty variable: PMM_SERVER_USER'
elif [ $PMM_SERVER_USER != 'admin' ];
then
    abort '1' 'Changing PMM_SERVER_USER is currently not supported because of a bug in Percona operator'
fi

if [ -z "$PMM_SERVER_PASSWORD" ];
then
    abort '1' 'Empty variable: PMM_SERVER_PASSWORD'
fi


#  Body
#  ====

log "ACTION: '$ACTION'"
log "WHAT: '$WHAT'"
mkdir info 2> /dev/null
run "kubectl config set-context --current --namespace=$PMM_SERVER_NAMESPACE"


if [ $ACTION == 'SHOW' ];
then
    # show info and exit

    echo
    showed=0

    if [ -z "$WHAT" ] || [[ "$WHAT" == 'ALL' ]] || [[ "$WHAT" == *'SYSTEM'* ]];
    then
        echo 'SYSTEM'
        echo '======'
        echo
        echo 'kubectl versions:'
        kubectl version
        echo
        echo 'Helm version:'
        helm version
        echo
        showed=1
    fi

    if [ -z "$WHAT" ] || [[ "$WHAT" == 'ALL' ]] || [[ "$WHAT" == *'SERVICES'* ]];
    then
        echo 'SERVICES'
        echo '========'
        echo
        kubectl get services monitoring-service
        echo
        showed=1
    fi

    if [ -z "$WHAT" ] || [[ "$WHAT" == 'ALL' ]] || [[ "$WHAT" == *'VOLUMES'* ]];
    then
        echo 'VOLUMES'
        echo '======='
        echo
        kubectl get pv | grep --color=never -E '^NAME|monitoring|pmm'
        echo
        showed=1
    fi

    if [ -z "$WHAT" ] || [[ "$WHAT" == 'ALL' ]] || [[ "$WHAT" == *'EVENTS'* ]];
    then
        echo 'EVENTS'
        echo '======'
        echo
        kubectl get events | grep --color=never -E '^LAST SEEN|service/monitoring-service'
        echo
        showed=1
    fi

    if [ $showed == 0 ];
    then
        abort '2' "Invalid object: $WHAT"
    fi

    success ''
elif [ $ACTION == 'UNINSTALL' ];
then
    # uninstall and exit
    if [ $WHAT == 'ALL' ] || [ $WHAT == 'RELEASE' ];
    then
        run 'helm uninstall monitoring'
    fi
    if [ $WHAT == 'ALL' ] || [ $WHAT == 'REPO' ] || [ $WHAT == 'REPOSITORY' ];
    then
        run 'helm repo remove percona'
    fi
    success 'Success'
elif [ $ACTION == 'REINSTALL' ];
then
    # uninstall and then continue
    if [ $WHAT == 'ALL' ] || [ $WHAT == 'RELEASE' ];
    then
        run 'helm uninstall monitoring'
    fi
    if [ $WHAT == 'ALL' ] || [ $WHAT == 'REPO' ] || [ $WHAT == 'REPOSITORY' ];
    then
        run 'helm repo remove percona'
    fi
fi


# We're here if ACTION=INSTALL or ACTION=REINSTALL

if [ $WHAT == 'ALL' ] || [ $WHAT == 'REPO' ] || [ $WHAT == 'REPOSITORY' ];
then
    run 'helm repo add percona https://percona.github.io/percona-helm-charts/'
    run 'helm repo update'
fi
if [ $WHAT == 'ALL' ] || [ $WHAT == 'RELEASE' ];
then
    if [ -r $PMM_SERVER_VALUES ] && [ ! -z $VERSION ];
    then
        run "helm install -f $PMM_SERVER_VALUES --version=$VERSION monitoring percona/pmm"
    elif [ -r $PMM_SERVER_VALUES ];
    then
        run "helm install -f $PMM_SERVER_VALUES monitoring percona/pmm"
    elif [ ! -z $VERSION ];
    then
        run "helm install --version=$VERSION monitoring percona/pmm"
    else
        run "helm install monitoring percona/pmm"
    fi
fi

helm get values monitoring

log '---'
echo 'The above data may be wrong because of a bug in Percona operators.' >> $LOG
echo 'The following data are provided by Kubernetes itself, so they should always be correct.' >> $LOG
helm get values monitoring >> $LOG

# Get PMM_SERVER_HOST from kubectl.
# If we can't, fail with an error.
# Otherwise, create a file that will be read by pmm-client.sh
PMM_SERVER_HOST=$( kubectl get services monitoring-service | tail -1 | tr -s ' ' | cut -d' ' -f4 )
if [ -z "$PMM_SERVER_HOST" ];
then
    abort '2' 'Apparently no PMM Server pod was created'
else
    echo 'SUCCESS'
fi
echo $PMM_SERVER_HOST > info/pmm-server-host
log "PMM Server host: $PMM_SERVER_HOST"
echo "PMM Server host: $PMM_SERVER_HOST"

success 'Success'


# TODO:
#   - Allow to use a non-standard server port

