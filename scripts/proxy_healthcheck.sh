#!/bin/bash

PROXY_NAME=$1
if [ $# -eq 0 ]; then 
 echo "Usage: "
 echo "$0 <parrent-proxy-name>"
 echo "parrent-proxy-name: dns of parrent proxy for cntlm"
 exit 1
fi

#remove colon 
PROXY_NAME=${PROXY_NAME%:*}

nslookup $PROXY_NAME > /dev/null 2>&1 
if [ $? -ne 0 ]; then
  echo "Parameter $PROXY_NAME is invalid, dns resolution not successful"
  exit 1
fi 

COMMAND_NAME=$(basename $0)
LOG=/var/log/${COMMAND_NAME}_$PROXY_NAME.log
IP_FILE=/tmp/${COMMAND_NAME}_$PROXY_NAME.ip

touch $IP_FILE 
touch $LOG

IP=$(nslookup $PROXY_NAME | grep 'Address:' | grep -v '#' | sort | xargs | sed 's/Address: //g')

if [[ "${IP}" != "$(cat ${IP_FILE})" ]]; then
    echo -n "$(date) | " >> $LOG
    echo -n "new proxy ip: ${IP} | " >> $LOG
    echo -n "old proxy ip: $(cat ${IP_FILE}) | " >> $LOG
    echo "restarting cntlm" >> $LOG
    systemctl restart cntlm
else
    echo "$(date) proxy ip still ok" >> $LOG
fi
echo -n "${IP}" > ${IP_FILE}

