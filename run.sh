#!/usr/bin/env bash

INTERVAL=${INTERVAL:-600}

namespaces=$(kubectl get namespaces -o custom-columns='NAME:.metadata.name' --no-headers 2>/dev/null)

while true
do
  echo "`date` === Network check started"
  for namespace in ${namespaces[@]}
  do
    service_list=$(kubectl get services -n $namespace -o custom-columns='NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP,PORT(S):.spec.ports[*].port' --no-headers 2>/dev/null)
    while read service
    do
      service_name=$(echo $service | awk '{print $1}')
      service_ip=$(echo $service | awk '{print $2}')
      service_port_list=$(echo $service | awk '{print $3}' | sed 's/,/ /g')

      #
      # Check service connectivity
      if [ "$service_ip" != "None" ]
      then
        endpoint=$(kubectl get ep -n $namespace $service_name --no-headers 2>/dev/null | awk '{print $2}')
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
    endpoint_list=$(kubectl get ep -n ${namespace} -o custom-columns='NAME:.metadata.name,IP(S):.subsets[*].addresses[*].ip,PORT(S):.subsets[*].ports[*].port,TARGET:.subsets[*].addresses[*].targetRef.name' --no-headers 2>/dev/null)
    while read endpoint
    do
      pod_ip_list=$(echo $endpoint | awk '{print $2}' | sed 's/,/ /g')
      pod_port_list=$(echo $endpoint | awk '{print $3}' | sed 's/,/ /g')
      pod_name_list=$(echo $endpoint | awk '{print $4}' | sed 's/,/ /g')

      if [ "$pod_ip_list" != "<none>" -a "$pod_port_list" != "<none>" -a "$pod_name_list" != "<none>" ]
      then
        index=0
        for pod_ip in ${pod_ip_list[@]}
        do
          index=$((index+1))
          pod_name=$(echo ${pod_name_list} | cut -d ' ' -f $index)
          for pod_port in ${pod_port_list[@]}
          do
            pod_host_ip=$(kubectl get po -n ${namespace} ${pod_name} -o jsonpath='{.status.hostIP}' 2>/dev/null)
            if [ "$pod_ip" != "$pod_host_ip" ]
            then
              echo -n "[POD CONNECT] - ${namespace}/${pod_name} (${pod_ip}:${pod_port}) "
              if nc -z -w 1 $pod_ip $pod_port > /dev/null
              then
                echo "[OK]"
              else
                echo "[FAILED]"
              fi
            fi
          done
        done
      fi
    done <<< "$endpoint_list"
  done
  echo "`date` === Done"
  sleep $INTERVAL
done
