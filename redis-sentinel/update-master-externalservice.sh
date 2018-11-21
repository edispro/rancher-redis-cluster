#!/bin/bash

REDIS_MASTER_UUID=$(curl -s http://rancher-metadata/latest/self/stack/services/redis-master/uuid)

if [ "${REDIS_MASTER_UUID}" = 'Not found' ]; then
	# Should create master.
	STACK_UUID=$(curl -s http://rancher-metadata/latest/self/stack/uuid)
	STACK_ID=$(curl "${CATTLE_URL}/stacks?uuid=${STACK_UUID}" -s -u "${CATTLE_ACCESS_KEY}:${CATTLE_SECRET_KEY}" | jq -r '.data[0].id')
	curl "${CATTLE_URL}/externalservices" -s -u "${CATTLE_ACCESS_KEY}:${CATTLE_SECRET_KEY}" -H 'Content-Type: application/json' -X POST -d "{
		\"name\": \"redis-master\",
		\"externalIpAddresses\": [\"$6\"],
		\"stackId\": \"${STACK_ID}\",
		\"startOnCreate\": true
	}"
else
	REDIS_MASTER_SERVICE_URL=$(curl "${CATTLE_URL}/services?uuid=${REDIS_MASTER_UUID}" -s -u "${CATTLE_ACCESS_KEY}:${CATTLE_SECRET_KEY}" | jq -r '.data[0].links.self')
	curl "${REDIS_MASTER_SERVICE_URL}" -u "${CATTLE_ACCESS_KEY}:${CATTLE_SECRET_KEY}" -H 'Content-Type: application/json' -X PUT -d "{\"externalIpAddresses\":[\"$6\"]}"
fi