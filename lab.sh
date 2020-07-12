#!/usr/bin/env bash

# Initialize command line parsing variables.
print_info=0
print_overview=0
up=0
down=0
prune=0
remove=0
build=0
dep_check=0
lab_level='all'
service_class='all'
red_team_services='none'
blue_team_services='none'
monitoring_services='none'
all_services=0

# Initialize global variables.
# Variable is used in src/labctl.bash.
# shellcheck disable=SC2034
working_dir="$PWD"
key_dir="${working_dir}/etc/keys"
auth_keys="${working_dir}/etc/authorized_keys"

# Include source files.
source src/info.bash
source src/labctl.bash
source src/helper.bash

# Initialize arrays.
lab_levels=(
            "all"
            "beginner"
            "intermediate"
            "expert"
            )

service_classes=(
            "all"
            "red_team"
            "blue_team"
            "victim"
            "monitoring"
            )

# Variable is used in src/helper.bash.
# shellcheck disable=SC2034
dependencies=(
            "docker"
            "docker-compose"
            "yq"
            "bash"
            "find"
            "sed"
            )

# Exit if no flags or arguments are given.
if [ "$#" -eq 0 ]; then
    print_usage
    exit 1
fi

# Parse command line arguments.
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_usage
            shift
            exit 0
            ;;
        -i|--info)
            print_info=1
            shift
            ;;
        -o|--overview)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                service_class=''
                for class in $2; do
                    if Helper-Array_contains "${class}" "${service_classes[*]}"\
                        ; then
                        service_class="${service_class} ${class}"
                    else
                        printf 'Error: Unknown class in: "%s" for %s\n'\
                            "$2" "$1" >&2
                        printf 'Possible arguments: %s\n' \
                            "$(Helper-Array_join "${service_classes[@]}")" >&2
                        exit 1
                    fi
                done
                shift 2
            else
                printf 'Error: Missing argument for %s\n' "$1" >&2
                exit 1
            fi
            print_overview=1
            ;;
        -B|--build)
            build=1
            shift
            ;;
        -u|--up)
            up=1
            shift
            ;;
        -d|--down)
            down=1
            shift
            ;;
        -R|--remove)
            remove=1
            shift
            ;;
        -p|--prune)
            prune=1
            shift
            ;;
        -C|--check-dependencies)
            dep_check=1
            shift
            ;;
        -r|--red-team)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                red_team_services="$2"
            else
                printf 'Error: Missing argument for %s\n' "$1" >&2
                exit 1
            fi
            shift 2
            ;;
        -b|--blue-team)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                blue_team_services="$2"
            else
                printf 'Error: Missing argument for %s\n' "$1" >&2
                exit 1
            fi
            shift 2
            ;;
        -m|--monitoring)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                monitoring_services="$2"
            else
                printf 'Error: Missing argument for %s\n' "$1" >&2
                exit 1
            fi
            shift 2
            ;;
        -l|--level)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                lab_level=''
                for level in $2; do
                    if Helper-Array_contains "${level}" "${lab_levels[*]}"; then
                        lab_level="${lab_level} ${level}"
                    else
                        printf 'Error: Unknown argument: %s for %s\n'\
                            "$2" "$1" >&2
                        printf 'Possible arguments: %s\n' \
                            "$(Helper-Array_join "${lab_levels[@]}")" >&2
                        exit 1
                    fi
                done
                lab_level="$(echo "${lab_level}" | awk '{$1=$1};1')"
                shift 2
            else
                printf 'Error: Missing argument for %s\n' "$1" >&2
                exit 1
            fi
            ;;
        -A|--all-services)
            all_services=1
            shift
            ;;
        *)
            # Unsupported options.
            printf 'Illegal option %s\n' "$1" >&2
            print_usage
            exit 1
            ;;
    esac
done

#
# Run lab accourding to parsed cmd line arguments.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: If none of the later occours.
#   - 1: If dependency missing / lab not in desired state.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: Error messages.
#
# Creates:
#   - Nothing.
#
main() {
    # Run dependency check.
    if [ "${dep_check}" -eq 0 ]; then
        if ! Helper-Check_dependencies > /dev/null 2>&1; then
            printf 'Error: Missing dependencies.\n' >&2
            printf 'Please run "%s -C" to check which dependency is missing.\n'\
                "$(basename "$0")" >&2
            exit 1
        fi
    fi

    # Print header.
    Helper-Print_header
    
    # Execute commads accourding to command line arguments.
    if [ "${print_info}" -eq 1 ]; then
        Helper-Check_lab_status && Info-Print_info
    fi
    
    if [ "${print_overview}" -eq 1 ]; then
        Helper-Check_lab_status && Info-Print_overview_table\
            "${service_class}"
    fi

    if [ "${up}" -eq 1 ]; then
        if Helper-Check_lab_status > /dev/null 2>&1; then
            printf 'Lab is already running.\n'
            exit 1
        else
            Labctl-Up\
                "${lab_level}"\
                "${red_team_services}"\
                "${blue_team_services}"\
                "${monitoring_services}"\
                "${all_services}"
            clear
            Helper-Print_header
            Info-Print_overview_table "${service_class}"
            Info-Print_info
        fi
    fi

    if [ "${down}" -eq 1 ]; then
        if ! Helper-Check_lab_status > /dev/null 2>&1; then
            printf 'Lab is not running.\n'
            exit 1
        else
            Labctl-Down
        fi
    fi

    if [ "${prune}" -eq 1 ]; then
        Labctl-Prune
    fi

    if [ "${dep_check}" -eq 1 ]; then
        Helper-Check_dependencies
    fi

    if [ "${build}" -eq 1 ]; then
        Labctl-Build_lab
    fi

    if [ "${remove}" -eq 1 ]; then
        Labctl-Remove_keys
    fi
}

# Run main function.
main
