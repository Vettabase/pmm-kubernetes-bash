#!/bin/bash


# Get the IP of PMM Server.


kubectl get services | grep --color=never monitoring-service | awk '{ print $4 }'

