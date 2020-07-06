# Variable is defined in ../lab.sh.
# shellcheck disable=SC2154
key_dir="${working_dir}/etc/keys"
auth_keys="${working_dir}/etc/authorized_keys"

# Generate compose yml for specific level.
#
# Arguments:
# - level: Create lab for specific level.
#   Possible values: [all, beginner, intermediate, expert]
# - red_team_services: Spawn additional red team services.
#   Possible values: [File names inside ./etc/services/red_team/.]
# - blue_team_services: Spawn additional blue team services.
#   Possible values: [File names inside ./etc/services/blue_team/.]
# - monitoring_services: Spawn additional monitring services.
#   Possible values: [File names inside ./etc/services/monitoring/.]
Labctl-Create_compose_file() {
    local level_array="$1"
    local path="${working_dir}/etc/services/victim"
    local red_team_services="$2"
    local blue_team_services="$3"
    local monitoring_services="$4"

    {
    printf '# Do not edit this file manually.\n'
    printf '# This file is auto generated by ./lab.sh.\n'
    printf '# To change this file edit files located in: "./etc/services/".\n'
    printf '# Afterwards restart the lab.\n'
    } > "${working_dir}/docker-compose.yml"

    cat "${working_dir}/etc/services/default.yml"\
        >> "${working_dir}/docker-compose.yml"

    for red_team_service in ${red_team_services}; do
        if  [ "${red_team_service}" = 'all' ]; then
            if [ "$(find "${working_dir}/etc/services/red_team"\
                -type f -name '*.yml' | wc -l)" -eq 0 ]; then
                printf 'Error: No configs red team configs found.\n' >&2
                exit 1
            else
                find "${working_dir}/etc/services/red_team"\
                    -type f -name '*.yml'\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        elif ! [ "${red_team_service}" = 'none' ]; then
            if [ "$(find "${working_dir}/etc/services/red_team"\
                -type f -name "${red_team_service}.yml" | wc -l)" -ne 1 ]; then
                printf 'Error: No config found for red_team service: %s.\n'\
                    "${red_team_service}" >&2
                exit 1
            else
                find "${working_dir}/etc/services/red_team"\
                    -type f -name "${red_team_service}.yml"\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        fi
    done

    for blue_team_service in ${blue_team_services}; do
        if  [ "${blue_team_service}" = 'all' ]; then
            if [ "$(find "${working_dir}/etc/services/blue_team"\
                -type f -name '*.yml' | wc -l)" -eq 0 ]; then
                printf 'Error: No configs blue team configs found.\n' >&2
                exit 1
            else
                find "${working_dir}/etc/services/blue_team"\
                    -type f -name '*.yml'\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        elif ! [ "${blue_team_service}" = 'none' ]; then
            if [ "$(find "${working_dir}/etc/services/blue_team"\
                -type f -name "${blue_team_service}.yml" | wc -l)" -ne 1 ]; then
                printf 'Error: No config found for blue_team service: %s.\n'\
                    "${blue_team_service}" >&2
                exit 1
            else
                find "${working_dir}/etc/services/blue_team"\
                    -type f -name "${blue_team_service}.yml"\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        fi
    done

    for monitoring_service in ${monitoring_services}; do
        if  [ "${monitoring_service}" = 'all' ]; then
            if [ "$(find "${working_dir}/etc/services/monitoring"\
                -type f -name '*.yml' | wc -l)" -eq 0 ]; then
                printf 'Error: No configs monitoring configs found.\n' >&2
                exit 1
            else
                find "${working_dir}/etc/services/monitoring"\
                    -type f -name '*.yml'\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        elif ! [ "${monitoring_service}" = 'none' ]; then
            if [ "$(find "${working_dir}/etc/services/monitoring"\
                -type f -name "${monitoring_service}.yml" | wc -l)" -ne 1 ]; then
                printf 'Error: No config found for monitoring service: %s.\n'\
                    "${monitoring_service}" >&2
                exit 1
            else
                find "${working_dir}/etc/services/monitoring"\
                    -type f -name "${monitoring_service}.yml"\
                    -exec sed -e 's/^/  /' {} \;\
                    >> "${working_dir}/docker-compose.yml"
            fi
        fi
    done

    for level in ${level_array}; do
        case "${level}" in
            all)
                find "${working_dir}/etc/services/victim/"\
                    -type f -name '*.yml'\
                    -exec sed -e 's/^/  /' {} \;\
                        >> "${working_dir}/docker-compose.yml"
                ;;
            beginner)
                if [ "$(find "${path}/beginner" -type f -name '*.yml'\
                    | wc -l)" -eq 0 ]; then
                    printf 'No services found for level: %s.\n' "${level}"
                    exit 1
                else
                    find "${path}/beginner" -type f -name '*.yml'\
                        -exec sed -e 's/^/  /' {} \;\
                        >> "${working_dir}/docker-compose.yml"
                fi
                ;;
            intermediate)
                if [ "$(find "${path}/intermediate" -type f -name '*.yml'\
                    | wc -l)" -eq 0 ]; then
                    printf 'No services found for level: %s.\n' "${level}"
                    exit 1
                else
                    find "${path}/intermediate" -type f -name '*.yml'\
                        -exec sed -e 's/^/  /' {} \;\
                        >> "${working_dir}/docker-compose.yml"
                fi
                ;;
            expert)
                if [ "$(find "${path}/expert" -type f -name '*.yml'\
                    | wc -l)" -eq 0 ]; then
                    printf 'No services found for level: %s.\n' "${level}"
                    exit 1
                else
                    find "${path}/expert" -type f -name '*.yml'\
                        -exec sed -e 's/^/  /' {} \;\
                        >> "${working_dir}/docker-compose.yml"
                fi
                ;;
            *)
                printf 'Error: No valid level: %s.\n' "${level}" >&2
                exit 1
        esac
    done
    printf '\n' >> "${working_dir}/docker-compose.yml"

    # Generate volume list.
    local volumes_tmp_file
    local volumes

    volumes_tmp_file="$(mktemp)"
    volumes="$(yq '.services | .[] | .volumes'\
        "${working_dir}/docker-compose.yml" -crM\
        | tr -d '\["\]' | cut -d ':' -f 1 | sed '/^null$/d')"

    printf '%s\n' 'volumes:' > "${volumes_tmp_file}"
    while read -r volume; do 
        printf '  %s:\n' "${volume}" >> "${volumes_tmp_file}"
    done <<<"${volumes}"

    # Add volume list to docker-compose.yml.
    cat "${volumes_tmp_file}" >> "${working_dir}/docker-compose.yml"
    rm "${volumes_tmp_file}"
}
    
# Check for existing ssh keys.
# If no keys present exit.
# If keys found add these to kali box, for ssh public key authentication.
Labctl-Bootstrap_ssh() {
    if [ "$(find "$HOME/.ssh/" -name '*.pub' | wc -l)" -eq 0 ]; then
        printf 'Error: No SSH public keys found in %s.\n\n' "$HOME/.ssh/" >&2
        printf 'Please generate SSH keys. For example: %s.\n'\
            'ssh-keygen -ted25519' >&2
        printf 'Otherwise you won'\''t be able to use the lab.\n' >&2
        exit 1
    fi
 
    Labctl-Remove_keys

    if ! [ -d "${key_dir}" ]; then
        mkdir -p "${key_dir}"
    fi
    
    find "$HOME/.ssh/" -name '*.pub' -exec cp {} "${key_dir}" \;
    find "${key_dir}" -name '*.pub' -exec cat {} \; >> "${auth_keys}"
}

# Build all needed ressources for the lab.
Labctl-Build_lab() {
    Labctl-Bootstrap_ssh
    docker-compose build
}

# Call function to generate compose yml and start the lab afterwards.
#
# Arguments:
# - level: Create lab for specific level.
#   Possible values: [all, beginner, intermediate, expert]
# - red_team_services: Spawn additional red team services.
#   Possible values: [File names inside ./etc/services/red_team/.]
# - blue_team_services: Spawn additional blue team services.
#   Possible values: [File names inside ./etc/services/blue_team/.]
# - monitoring_services: Spawn additional monitring services.
#   Possible values: [File names inside ./etc/services/monitoring/.]
Labctl-Up() {
    local level="$1"
    local red_team_services="$2"
    local blue_team_services="$3"
    local monitoring_services="$4"
    local run_dir
    run_dir="$HOME/.local/var/run/pentest_lab"

    if [ -d "${run_dir}" ]; then
        rm -rf "${run_dir}"
    fi

    mkdir -p "${run_dir}"

    {
    printf 'level: %s\n' "${level}"
    printf 'red_team_services: %s\n' "${red_team_services}"
    printf 'blue_team_services: %s\n' "${blue_team_services}"
    printf 'monitoring_services: %s\n' "${monitoring_services}"
    } >> "${run_dir}/info"

    Labctl-Create_compose_file\
        "${level}"\
        "${red_team_services}"\
        "${blue_team_services}"\
        "${monitoring_services}"
    Labctl-Build_lab
    docker-compose up -d --remove-orphans || Labctl-Emergency_down
}

# Remove orphaned files if lab startup fails.
Labctl-Emergency_down() {
    local run_dir
    run_dir="$HOME/.local/var/run/pentest_lab"


    if [ -d "${run_dir}" ]; then
        rm -rf "${run_dir}"
    fi

    docker-compose down --remove-orphans
}

# Stop the lab.
Labctl-Down() {
    local run_dir
    run_dir="$HOME/.local/var/run/pentest_lab"

    docker-compose down --remove-orphans

    if [ -d "${run_dir}" ]; then
        rm -rf "${run_dir}"
    fi
}

# Remove all ressources owned by the lab - reset the lab.
Labctl-Prune() {
    docker-compose down --remove-orphans --rmi all --volumes
    docker-compose rm -fsv
    Labctl-Remove_keys
}

# Remove ssh keys from local directory.
Labctl-Remove_keys() {
    printf 'Removing: %s.\n' "${key_dir}"
    if [ -d "${key_dir}" ]; then
        rm -r "${key_dir}"
    fi

    printf 'Removing: %s.\n' "${auth_keys}"
    if [ -f "${auth_keys}" ]; then
        rm "${auth_keys}"
    fi
}
