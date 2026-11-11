#!/bin/bash
set -e

HOSTNAME="$(hostname)"
echo "Starting RabbitMQ for host: ${HOSTNAME}"

wait_for_node() {
  rabbitmqctl wait "/var/lib/rabbitmq/mnesia/rabbit@${HOSTNAME}.pid" --timeout 60
}

if [ -z "${JOIN_CLUSTER_HOST}" ]; then
  /usr/local/bin/docker-entrypoint.sh rabbitmq-server &
  wait_for_node
else
  /usr/local/bin/docker-entrypoint.sh rabbitmq-server -detached
  wait_for_node
  rabbitmqctl stop_app
  rabbitmqctl join_cluster "rabbit@${JOIN_CLUSTER_HOST}"
  rabbitmqctl start_app
fi

tail -f /dev/null
