#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y freeradius freeradius-mysql freeradius-utils mariadb-server mariadb-client
systemctl enable --now mariadb

mysql -e CREATE
