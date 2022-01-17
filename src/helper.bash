#
# Define usage text and print this text.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Usage text.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_helper_printUsage() {
    local usage

    usage="\e[1m\e[31mUsage: $(basename "$0") [OPTIONS]\e[0m

    Conrol local pentest lab.

  \e[32m-h | --help\e[0m                \e[32mPrint\e[0m this usage.
  \e[32m-i | --info\e[0m                \e[32mPrint\e[0m generall information.
  \e[32m-o | --overview\e[0m TEXT       \e[32mPrint\e[0m overview table of services. \e[32m[default: all]\e[0m
                                Options: [all|red_team|blue_team|victim|monitoring]
                                TEXT is a space separated list like: 'red_team victim' or 'all'.
  \e[32m-B | --build\e[0m               \e[32mBuild\e[0m the lab and not start it.
  \e[32m-u | --up\e[0m                  \e[32mStart\e[0m pentest lab if not allready running.
  \e[32m-d | --down\e[0m                \e[32mStop\e[0m pentest lab if not allready stopped.
  \e[32m-R | --remove\e[0m              \e[32mRemove\e[0m files like SSH keys from local dir.
  \e[32m-p | --prune\e[0m               \e[32mPrune\e[0m pentest lab after stopping.
                                This will delete images, networks, containers and volumes.
                                All data stored in persistent volumes will be lost.
  \e[32m-C | --check-dependencies\e[0m  \e[32mCheck\e[0m for all mandatory dependencies.
  \e[32m-r | --red-team\e[0m TEXT       \e[32mSpecify\e[0m additional red team services to be spawned. \e[32m[default: none]\e[0m
                                Options: [all|File names inside ./etc/services/red_team/]
                                TEXT is a space separated list like: 'ninjas zap' or 'zap'.
                                For example: to spawn ninjas.yml use --red_team 'ninjas'.
  \e[32m-b | --blue-team\e[0m TEXT      \e[32mSpecify\e[0m additional blue team services to be spawned. \e[32m[default: none]\e[0m
                                Options: [all|File names inside ./etc/services/blue_team/]
                                TEXT is a space separated list like: 'snort vast' or 'snort'.
                                For example: to spawn snort.yml use --blue_team 'snort'.
  \e[32m-m | --monitoring\e[0m TEXT     \e[32mSpecify\e[0m additional monitoring services to be spawned. \e[32m[default: none]\e[0m
                                [all|Options: File names inside ./etc/services/monitoring/]
                                TEXT is a space separated list like: 'grafana prometheus' or 'grafana'.
                                For example: to spawn grafana.yml use --monitoring 'grafana'.
  \e[32m-l | --level\e[0m TEXT          \e[32mSpecify\e[0m level of victim services. \e[32m[default: all]\e[0m
                                Options: [all,beginner,intermediate,expert]
                                TEXT is a space separated list like: 'beginner intermediate' or 'beginner'.
  \e[32m-A | --all-services\e[0m        \e[32mSet\e[0m lab to run all available services."

    printf '%b\n' "${usage}"
}

#
# Check if docker daemon is running.
# Afterwards check if cluster named "pentest_lab" is running.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: If everything is up an running.
#   - 1: If something needed is not running.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: If something is not running.
#
# Creates:
#   - Nothing
#
_helper_isUp() {
    # Check if docker daemon is running.
    if [ -z "$(cat /var/run/docker.pid 2>/dev/null)" ]; then
        printf "Docker daemon seems to be not running.\n" >&2
        return 1
    fi

    running="$(docker ps --filter 'label=cluster=pentest_lab' -q)"
    if [ -z "${running}" ]; then
        printf "Pentesting lab seems not to be up.\n" >&2
        return 1
    fi
}

#
# Print lab header in ascii art.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Lab header.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_helper_printHeader() {
    echo -e '\e[32m\e[1m'
    echo -e '################################################################################'
    echo -e '#            ____             __            __     __          __              #'
    echo -e '#           / __ \___  ____  / /____  _____/ /_   / /   ____ _/ /_             #'
    echo -e '#          / /_/ / _ \/ __ \/ __/ _ \/ ___/ __/  / /   / __ `/ __ \            #'
    echo -e '#         / ____/  __/ / / / /_/  __(__  ) /_   / /___/ /_/ / /_/ /            #'
    echo -e '#        /_/    \___/_/ /_/\__/\___/____/\__/  /_____/\__,_/_.___/             #'
    echo -e '#                                                                              #'
    echo -e '################################################################################'
    echo -e '\e[0m'
}

#
# Check if array_string contains value.
#
# Arguments:
#   - $1 = value: Value to check for in array.
#   - $2 = array_string: An array formatted as a single string.
#
# Returns:
#   - 0: If array_string contains value.
#   - 1: If array_string does not contain value.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_helper_arrayContains() {
    local value
    local array_string
    local class

    value="$1"
    array_string="$2"

    for class in ${array_string}; do
        if [ "${class}" = "${value}" ]; then
            return 0
        fi
    done
    return 1
}

#
# Join array to comma separated string and print.
#
# Arguments:
#   - $@: All items of an array.
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Comma separated string containing all array items.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_helper_arrayJoin() {
    local joined

    printf -v joined '%s,' "$@"
    joined="${joined%?}"
    printf '%s' "${joined}"
}

#
# Check if all needed software/commands are present to run this lab.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: If all commands are present.
#   - 1: If not all commands are present.
#
# Prints:
#   - stdout: Message wether checked command is present or not.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_helper_checkDependencies() {
    local return_code=0
    local dependency

    # Variable is defined in ../lab.sh.
    # shellcheck disable=SC2154
    for dependency in "${dependencies[@]}"; do
        if command -v "${dependency}" > /dev/null 2>&1; then
            printf '%-15s %b\n' "${dependency}" "\e[1m\e[32m[OK]\e[0m"
            if [ "${dependency}" == 'yq' ]; then
                repo='https://github.com/kislyuk/yq'
                if ! yq --help | grep -q "${repo}"; then
                    printf '%-15s %b\n\n%s %s %b\n\n' \
                        "${dependency}" \
                        "\e[1m\e[31m[Wrong yq]\e[0m" \
                        "Please install yq written in Python." \
                        "Found here:" \
                        "\e[32m${repo}\e[0m"
                    return_code=1
                else
                    printf '%-15s %b\n' \
                        "${dependency}" "\e[1m\e[32m[Right yq]\e[0m"
                fi
            fi
        else
            printf '%-15s %b\n' "${dependency}" "\e[1m\e[31m[NOT FOUND]\e[0m"
            return_code=1

        fi
    done
    return "${return_code}"
}
