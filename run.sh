#!/usr/bin/env bash

INTERVAL=${INTERVAL:-600}

set -e

namespaces=$(kubectl get namespaces -o custom-columns='NAME:.metadata.name' --no-headers)

while true
do
  echo "`date` === Network check started"
  for namespace in ${namespaces[@]}
  do
    service_list=$(kubectl get services -n $namespace -o custom-columns='NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP,PORT(S):.spec.ports[*].port' --no-headers)
    while read service
    do
      service_name=$(echo $service | awk '{print $1}')
      service_ip=$(echo $service | awk '{print $2}')
      service_port_list=$(echo $service | awk '{print $3}' | sed 's/,/ /g')

      #
      # Check service connectivity
      if [ "$service_ip" != "None" ]
      then
        endpoint=$(kubectl get ep -n $namespace $service_name --no-headers | awk '{print $2}')
        if [ "${endpoint}" != "" -a "${endpoint}" != "<none>" ]
        then
          for service_port in ${service_port_list[@]}
          do
            echo -n "[SERVICE CONNECT] - ${namespace}/${service_name} (${service_ip}:${service_port}) "
            if nc -z -w 1 $service_ip $service_port > /dev/null
            then
              echo "[OK]"
            else
              echo "[FAILED]"
            fi
          done
        fi
      fi

      #
      # Check service dns resolution
      if [ "$service_name" != "" ]
      then
        echo -n "[DNS] - ${namespace}/${service_name} "
        if host ${service_name}.${namespace} > /dev/null
        then
          echo "[OK]"
        else
          echo "[FAILED]"
        fi
      fi
    done <<< "$service_list"

    #
    # Check pod connectivity
    endpoint_list=$(kubectl get ep -n ${namespace} -o custom-columns='NAME:.metadata.name,IP(S):.subsets[*].addresses[*].ip,PORT(S):.subsets[*].ports[*].port' --no-headers)
    while read endpoint
    do
      pod_ip_list=$(echo $endpoint | awk '{print $2}' | sed 's/,/ /g')
      pod_port_list=$(echo $endpoint | awk '{print $3}' | sed 's/,/ /g')

      if [ "$pod_ip_list" != "<none>" -a "$pod_port_list" != "<none>" ]
      then
        for pod_ip in ${pod_ip_list[@]}
        do
          for pod_port in ${pod_port_list[@]}
          do
            pod_name=$(kubectl get po -n ${namespace} -o wide | grep -v Error | grep $pod_ip | awk '{print $1}')
            echo -n "[POD CONNECT] - ${namespace}/${pod_name} (${pod_ip}:${pod_port}) "
            if nc -z -w 1 $pod_ip $pod_port > /dev/null
            then
              echo "[OK]"
            else
              echo "[FAILED]"
            fi
          done
        done
      fi
    done <<< "$endpoint_list"
  done
  echo "`date` === Done"
  sleep $INTERVAL
done
