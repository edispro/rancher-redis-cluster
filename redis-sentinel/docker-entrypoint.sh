#!/bin/bash

function leader_ip {
  echo -n $(curl -s http://rancher-metadata/latest/stacks/$1/services/$2/containers/0/primary_ip)
}

giddyup service wait scale --timeout 120
stack_name=`echo -n $(curl -s http://rancher-metadata/latest/self/stack/name)`
my_ip=$(giddyup ip myip)
redis_master_ip=$(leader_ip $stack_name redis-server)
sentinel_master_ip=$(giddyup leader get)

sed -i -E "s/^ *# *bind +.*$/bind 0.0.0.0/g" /usr/local/etc/redis/sentinel.conf
sed -i -E "s/^ *dir +.*$/dir .\//g" /usr/local/etc/redis/sentinel.conf
sed -i -E "s/^[ #]*sentinel announce-ip .*$/sentinel announce-ip ${my_ip}/" /usr/local/etc/redis/sentinel.conf
sed -i -E "s/^[ #]*sentinel announce-port .*$/sentinel announce-port 26379/" /usr/local/etc/redis/sentinel.conf
sed -i -E "s/^[ #]*sentinel monitor ([A-z0-9._-]+) 127.0.0.1 ([0-9]+) ([0-9]+).*$/sentinel monitor \1 ${redis_master_ip} \2 \3/g" /usr/local/etc/redis/sentinel.conf # Only replace when it's 127.0.0.1, meaning we're running for the first time, otherwise we keep old configuration.

if [ -n "${CATTLE_ACCESS_KEY}" ]; then
	sed -i -E "s/^[ #]*sentinel +client-reconfig-script +([A-z0-9._-]+).*$/sentinel client-reconfig-script \1 \/update-master-externalservice.sh/" /usr/local/etc/redis/sentinel.conf
	if [ "${my_ip}" = "${sentinel_master_ip}" ]; then
		# We are the sentinel master and the redis-master external service doesn't exists yet.
		REDIS_MASTER_UUID=$(curl -s http://rancher-metadata/latest/self/stack/services/redis-master/uuid)
		if [ "${REDIS_MASTER_UUID}" = 'Not found' ]; then
			/update-master-externalservice.sh x x x x x "${redis_master_ip}" 6379
		fi
	fi
else
	echo "*** WARNING: redis-master external service management disabled, add labels io.rancher.container.create_agent=true and io.rancher.container.agent.role=environment on redis-sentinel containers to enable it."
fi

if [ -n "${SENTINEL_DOWN_AFTER_MILLISECONDS}" ]; then
	sed -i -E "s/^[ #]*sentinel down-after-milliseconds ([A-z0-9._-]+) .*$/sentinel down-after-milliseconds \1 ${SENTINEL_DOWN_AFTER_MILLISECONDS}/" /usr/local/etc/redis/sentinel.conf
fi

if [ -n "${SENTINEL_FAILOVER_TIMEOUT}" ]; then
	sed -i -E "s/^[ #]*sentinel failover-timeout ([A-z0-9._-]+) .*$/sentinel failover-timeout \1 ${SENTINEL_FAILOVER_TIMEOUT}/" /usr/local/etc/redis/sentinel.conf
fi

exec docker-entrypoint.sh "$@"
