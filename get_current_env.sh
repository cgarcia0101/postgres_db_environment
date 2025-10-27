#!/bin/bash

# Path to the HAProxy configuration file
CONFIG_PATH="haproxy/haproxy.cfg"

# Check if the file exists
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: Configuration file not found at $CONFIG_PATH"
  exit 1
fi

# Extract the default_backend value using grep and awk
DEFAULT_BACKEND=$(grep -E '^\s*default_backend' "$CONFIG_PATH" | awk '{print $2}')

# Check if a default_backend value was found
if [[ -n "$DEFAULT_BACKEND" ]]; then
  # Assuming backend names follow the format <environment>-db
  ENVIRONMENT=$(echo "$DEFAULT_BACKEND" | cut -d'-' -f1)
  echo "Current environment: $ENVIRONMENT"
else
  echo "Error: No default_backend value found in the configuration file."
  exit 1
fi
