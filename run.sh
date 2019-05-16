#!/usr/bin/env bash

INTERVAL=${INTERVAL:-600}

set -e

namespaces=$(kubectl get namespaces)

while true
do
  echo "`date` === Network check started"
  for namespace in ${namespaces[@]}
  do
    service_list=$(kubectl get svc -n $namespace -o name)
    for service in ${service_list[@]}
    do
      pod_ip=$(kubectl get $service -n $namespace -o jsonpath='{.spec.clusterIP}')
      echo -n "[PING] - ${service} (${pod_ip}) "
      if ping -c 1 -t 1 $pod_ip >/dev/null
      then
        echo "[OK]"
      else
        echo "[FAILED]"
      fi

      echo -n "[DNS] - ${service} "
      if host ${service#*/}.$namespace
      then
        echo "[OK]"
      else
        echo "[FAILED]"
      fi
    done
  done
  echo "`date` === Done"
  sleep $INTERVAL
done
