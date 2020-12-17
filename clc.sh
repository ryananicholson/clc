#!/bin/bash
IFS=$'\n'
function usage() {
  echo -e "\033[31m[!]\033[0m Usage: clc.sh <times|countries> <azure|aws> [offline.json]"
  exit 1
}

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
  usage
fi

if [[ $2 == "aws" ]]; then
  if [ $# -eq 3 ]; then
    IPS=$(cat $3 | jq -r '.Events[].CloudTrailEvent' | jq '. | .eventTime + " " + .sourceIPAddress' | sort) 
  else
    IPS=$(aws cloudtrail lookup-events --max-results 10000 | jq -r '.Events[].CloudTrailEvent' | jq '. | .eventTime + " " + .sourceIPAddress' | sort)
  fi 
elif [[ $2 == "azure" ]]; then
  if [ $# -eq 3 ]; then
    IPS=$(cat $3 | jq '.[] | .eventTimestamp + " " + .claims.ipaddr' | sort)
  else
    IPS=$(az monitor activity-log list --offset 7d | jq '.[] | .eventTimestamp + " " + .claims.ipaddr' | sort)
  fi
else
  usage
fi

if [[ $1 == "times" ]]; then
  echo -e "Event Time\t\t\tTime Zone\t\tIP Address\n============================================"
  for i in ${IPS[@]}; do
    IP=$(echo $i | cut -d ' ' -f2 | tr -d '"')
    if [[ $(echo $IP | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$") ]]; then
      TZONE=$(curl -s http://ip-api.com/json/$IP | jq -r .timezone)
      EVENTTIME=$(TZ=$TZONE date -d@$(date -d"$(echo $i | cut -d ' ' -f1 | cut -d '.' -f1 | tr -d '\"')" "+%s"))
      echo -e "$EVENTTIME\t$TZONE\t$IP"
      if [[ $(for i in ${IPS[@]}; do echo $i; done | wc -l) > 45 ]]; then
        sleep 2
      fi
    fi
  done
elif [[ $1 == "countries" ]]; then
  echo -e "#\tIP Address\tCountry\n============================================"
  IPUNIQ=$(for i in ${IPS[@]}; do echo $i | cut -d ' ' -f2 | tr -d '"'; done | sort | uniq -c)
  for i in ${IPUNIQ[@]}; do
    COUNTRY=$(curl -s http://ip-api.com/json/$(echo $i | awk '{print $2}') | jq -r .country)
    echo -e "$i\t$COUNTRY"
    if [[ $(for i in ${IPUNIQ[@]}; do echo $i; done | wc -l) > 45 ]]; then
      sleep 2
    fi
  done
else
  usage
fi
