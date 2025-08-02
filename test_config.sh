#!/bin/bash
source modules/cli.sh
parse_cli_arguments config list
echo "CONFIG_COMMAND: $CONFIG_COMMAND"
echo "CONFIG_SUBCOMMAND: $CONFIG_SUBCOMMAND"
echo "About to source core..."
source modules/core.sh >/dev/null 2>&1
echo "About to source config..."
source modules/config.sh >/dev/null 2>&1
echo "About to call handle_config_command..."
handle_config_command "$CONFIG_SUBCOMMAND"

