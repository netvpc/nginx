#!/bin/bash

# ANSI colour codes
COLOR_INFO="\033[1;36m[INFO]\033[0m"        # Cyan
COLOR_SUCCESS="\033[1;32m[Success]\033[0m"  # Green
COLOR_ERROR="\033[1;31m[Error]\033[0m"      # Red
COLOR_WARN="\033[1;33m[Warn]\033[0m"        # Yellow

# Check the PROXY_TYPE environment variable and validate it
if [[ -z "$PROXY_TYPE" ]]; then
  echo -e "$COLOR_INFO The 'PROXY_TYPE' environment variable hasn't been set."
  echo -e "$COLOR_WARN Cancelling the script and running the container with the default configuration."
  exit 0
fi

# Function to add the stream {} block
add_stream_block() {
  local nginx_conf=$1
  local stream_block

  read -r -d '' stream_block <<EOF
stream {
  upstream db {
    server ${DATABASE_HOST}:${DATABASE_PORT};
  }

  log_format  main  '\$remote_addr [\$time_local] '
                    '\$protocol \$status \$bytes_sent \$bytes_received '
                    '\$session_time';

  access_log  /var/log/nginx/access.log  main;

  server {
    listen ${DATABASE_PORT};
    proxy_pass db;
  }
}
EOF

  if echo "$stream_block" >> "$nginx_conf"; then
    echo -e "$COLOR_SUCCESS The stream {} block has been successfully added to the nginx configuration file."
  else
    echo -e "$COLOR_ERROR Couldn't add the stream {} block."
    echo -e "$COLOR_WARN Cancelling the script and running the container with the default configuration."
    exit 1
  fi
}

# Check execution conditions based on PROXY_TYPE
case "$PROXY_TYPE" in
  mysql|pgsql|postgresql|pg|mongo)
    NGINX_CONF=${NGINX_CONF:-"/etc/nginx/nginx.conf"}
    echo -e "$COLOR_INFO PROXY_TYPE is set to '${PROXY_TYPE}'. Continuing with the script."
    
    # Check DATABASE_HOST and DATABASE_PORT environment variables
    if [[ -z "$DATABASE_HOST" || -z "$DATABASE_PORT" ]]; then
        echo -e "$COLOR_INFO The 'DATABASE_HOST' or 'DATABASE_PORT' environment variable isn't set."
        echo -e "$COLOR_WARN Cancelling the script and running the container with the default configuration."
        exit 0
    fi

    # Remove the existing http {} block
    if sed -i '/http {/,/}/d' "$NGINX_CONF"; then
      echo -e "$COLOR_SUCCESS The existing http {} block has been successfully removed."
    else
      echo -e "$COLOR_WARN Couldn't remove the http {} block. Exiting the script."
      exit 1
    fi

    # Add the stream {} block
    add_stream_block "$NGINX_CONF"
    
    echo -e "$COLOR_SUCCESS The NGINX configuration file has been successfully updated."
    echo -e "$COLOR_SUCCESS Starting With Stream \033[1;34m${PROXY_TYPE}\033[0m"
    ;;
  *)
    echo -e "$COLOR_ERROR Invalid PROXY_TYPE value. It must be one of ('mysql', 'pgsql', 'postgresql', 'pg', 'mongo')."
    echo -e "$COLOR_WARN Cancelling the script and running the container with the default configuration."
    exit 0
    ;;
esac
