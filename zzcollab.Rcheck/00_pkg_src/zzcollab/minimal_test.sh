echo "Testing basic config command"
source modules/cli.sh
CONFIG_COMMAND=true
CONFIG_SUBCOMMAND="list"
echo "CONFIG_COMMAND: $CONFIG_COMMAND"
if [[ "${CONFIG_COMMAND:-false}" == "true" ]]; then
    echo "Config command detected"
    source modules/core.sh >/dev/null 2>&1
    source modules/config.sh >/dev/null 2>&1
    echo "About to call handle_config_command"
    handle_config_command "$CONFIG_SUBCOMMAND"
else
    echo "Config command not detected"
fi
