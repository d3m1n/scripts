#!/bin/bash

set -e

mongo_eval() {
    local port=$1
    local command=$2
    mongosh admin --quiet --host localhost --port $port --tls \
    --tlsCertificateKeyFile /mongodb/security/shared.pem \
    --tlsCAFile /mongodb/security/ca.pem \
    --tlsAllowInvalidHostnames \
    --eval "$command"
}

get_state() {
    mongo_eval $1 'db.adminCommand({replSetGetStatus:1}).myState'
}

rs_step_down() {
    echo "STEP DOWN!"
    mongo_eval $1 'db.adminCommand({replSetStepDown:120,secondaryCatchUpPeriodSecs:15})'
}

sudo ss -tlnp | awk '/mongod/ {gsub(/.*:/,"",$4); print $4}' | while read port; do
    state=$(get_state $port)
    case $state in
        1)
            echo "PRIMARY"
            rs_step_down $port
            sleep 5
            if [ $(get_state $port) -eq 1 ]; then
                echo "Port: ${port}. State has not changed!"
                exit 1
            fi
            ;;
        2)
            echo "SECONDARY"
            ;;
        *)
            echo "State: ${state}. Requires manual intervention."
            exit 1
            ;;
    esac
done
