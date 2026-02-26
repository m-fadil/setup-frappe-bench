#!/usr/bin/env bash
set -euo pipefail

bench init --skip-redis-config-generation --ignore-exist --frappe-branch=version-16 --dev frappe-bench
cd frappe-bench

bench set-config -g db_host mariadb
bench set-config -g db_port 3306
bench set-config -g redis_cache redis://redis-cache:6379
bench set-config -g redis_queue redis://redis-queue:6379
bench set-config -g redis_socketio redis://redis-socketio:6379
