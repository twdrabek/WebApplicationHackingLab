# Print usage.
print_usage() {
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
                                TEXT is a space separated list like: 'beginner intermediate' or 'beginner'."

    printf '%b\n' "${usage}"
}

# Check if everything needed is up and running.
Helper-Check_lab_status() {
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

# Print header.
Helper-Print_header() {
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

# Check if array contains key.
Helper-Array_contains() {
    key="$1"
    array_string="$2"
    for class in ${array_string}; do
        if [ "${class}" = "${key}" ]; then
            return 0
        fi
    done
    return 1
}

# Join array to comma separated string.
Helper-Array_join() {
    local joined
    printf -v joined '%s,' "$@"
    joined="${joined%?}"
    printf '%s' "${joined}"
}

# Dependency check. Returns 1 if one or more needed commands are missing.
Helper-Check_dependencies() {
    local return_code=0
    # Variable is defined in ../lab.sh.
    # shellcheck disable=SC2154
    for dependency in "${dependencies[@]}"; do
        if command -v "${dependency}" > /dev/null 2>&1; then
            printf '%-15s %b\n' "${dependency}" "\e[1m\e[32m[OK]\e[0m"
        else
            printf '%-15s %b\n' "${dependency}" "\e[1m\e[31m[NOT FOUND]\e[0m"
            return_code=1

        fi
    done
    return "${return_code}"
}
