#
# Generate tmp file with all needed data to print overview table.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: Nothing.
#
# Creates:
#   - Files:
#      - victim_tmp_file: Temp file containing victim service data.
#      - monitoring_tmp_file: Temp file containing monitoring service data.
#      - red_team_tmp_file: Temp file containing red_team service data.
#      - blue_team_tmp_file: Temp file containing blue_team service data.
#      - overall_tmp_file: Temp file containing all service data.
#
_info_buildOverview() {
    local all
    local container
    local ip
    local hostname
    local class
    local level
    local internal_address
    local port
    local ext_port
    local exposed_address
    local internal_ports
    local format_string
    local outfile

    # Create tmp files.
    victim_tmp_file="$(mktemp)"
    monitoring_tmp_file="$(mktemp)"
    red_team_tmp_file="$(mktemp)"
    blue_team_tmp_file="$(mktemp)"
    overall_tmp_file="$(mktemp)"

    # Get all docker container ids.
    all="$(docker ps -q --filter 'label=cluster=pentest_lab')"

    # Get container information and print table body.
    for container in ${all}; do
        format_string='{{range .NetworkSettings.Networks}} '
        format_string+='{{.IPAddress}}{{end}} {{.Config.Hostname}} '
        format_string+='{{.Config.Labels.class}} '
        format_string+='{{.Config.Labels.level}}'
        read -r ip hostname class level <<<"$(docker inspect -f \
            "${format_string}" \
            "${container}")"

        # Search for internal and exposed ports.
        if [ "${hostname}" = 'kali' ]; then
            internal_address="-"
            exposed_address="${ip}:22"
            printf "%s,%s,%s,%s,%s,%s,%s\n"\
                "${level}" "${class}" "${container}" "${ip}" "${hostname}"\
                "-" "${exposed_address}" >> "${red_team_tmp_file}"
        else
            internal_ports="$(docker inspect -f \
                '{{json .NetworkSettings.Ports}}'\
                "${container}" | jq -r 'keys[]' | cut -d'/' -f1)"
            
           case "${class}" in
               victim)
                   outfile="${victim_tmp_file}"
                   ;;
               monitoring)
                   outfile="${monitoring_tmp_file}"
                   ;;
               red_team)
                   outfile="${red_team_tmp_file}"
                   ;;
               blue_team)
                   outfile="${blue_team_tmp_file}"
                   ;;
           esac

            if [ -n "${internal_ports}" ]; then
                for port in ${internal_ports}; do
                    internal_address="${ip}:${port}"
                    ext_port="$(\
                        docker port "${container}" "${port}" 2>/dev/null\
                        | cut -d':' -f2)"

                    if [ -z "${ext_port}" ]; then
                        exposed_address="-"
                    else
                        exposed_address="localhost:${ext_port}"
                    fi

                    printf "%s,%s,%s,%s,%s,%s,%s\n"\
                        "${level}" "${class}" "${container}" "${ip}"\
                        "${hostname}" "${internal_address}"\
                        "${exposed_address}" >> "${outfile}"

                done
            else
                printf "%s,%s,%s,%s,%s,%s,%s\n"\
                    "${level}" "${class}" "${container}" "${ip}"\
                    "${hostname}" "${internal_address:--}"\
                    "${exposed_address:--}" >> "${outfile}"
            fi
        fi
    done
    
    cat "${victim_tmp_file}" "${red_team_tmp_file}" "${blue_team_tmp_file}"\
        "${monitoring_tmp_file}" > "${overall_tmp_file}"
}

#
# Print tmp tables created earlier.
#
# Arguments:
#   - $1 = class: print overview table for specific class.
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Print overview table.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_info_printOverview() {
    local classes
    local class
    local level
    local class
    local id
    local ip
    local hostname
    local internal_address
    local exposed_address

    _info_buildOverview

    classes=''
    for class in ${1}; do
        case "$class" in
            all)
                classes='red_team victim blue_team monitoring'
                break
                ;;
            red_team)
                classes="${classes} ${class}"
                ;;
            blue_team)
                classes="${classes} ${class}"
                ;;
            victim)
                classes="${classes} ${class}"
                ;;
            monitoring)
                classes="${classes} ${class}"
                ;;
        esac
    done

    # Get lenght of table columns.
    local longest_level=1
    local longest_id=1
    local longest_ip=1
    local longest_hostname=1
    local longest_internal_address=1
    local longest_exposed_address=1

    while IFS=, read -r level class id ip hostname internal_address\
        exposed_address; do
        if [ ! "${level}" = "<no value>" ]; then
            if [ "$((longest_level-1))" -lt "${#level}" ]; then
                longest_level="${#level}"
                longest_level="$((longest_level+1))"
            fi
        fi
        if [ "$((longest_id-1))" -lt "${#id}" ]; then
            longest_id="${#id}"
            longest_id="$((longest_id+1))"
        fi
        if [ "$((longest_ip-1))" -lt "${#ip}" ]; then
            longest_ip="${#ip}"
            longest_ip="$((longest_ip+1))"
        fi
        if [ "$((longest_hostname-1))" -lt "${#hostname}" ]; then
            longest_hostname="${#hostname}"
            longest_hostname="$((longest_hostname+1))"
        fi
        if [ "$((longest_internal_address-1))" -lt "${#internal_address}" ]; \
            then
            longest_internal_address="${#internal_address}"
            longest_internal_address="$((longest_internal_address+1))"
        fi
        if [ "$((longest_exposed_address-1))" -lt "${#exposed_address}" ]; then
            longest_exposed_address="${#exposed_address}"
            longest_exposed_address="$((longest_exposed_address+1))"
        fi
    done < "${overall_tmp_file}"

    # Print table header.
    table_width="$((longest_id+longest_ip+longest_hostname+\
        longest_internal_address+longest_exposed_address+longest_level+5))"
    header_width="$((table_width-9))"

    printf "|%-${table_width}s|\n" | tr ' ' -
    printf "|%b %-${header_width}s|\n" "\e[38m\e[1mSERVICES\e[0m" " "

    for class in ${classes}; do
        case "${class}" in
            victim)
                if [ -n "$(cat "${victim_tmp_file}")" ]; then
                    header_width="$((table_width-7))"
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%b %-${header_width}s|\n" "\e[33m\e[1mVICTIM\e[0m" " "
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed_address}s|%-${longest_level}s|\n"\
                        "ID" "IP" "Hostname" "Lab internal" "Exposed at" "Level"
                    printf "%-${longest_id}s %-${longest_ip}s %-${longest_hostname}s %-${longest_internal_address}s %-${longest_exposed_address}s %-${longest_level}s %s\n"\
                        "|" "|" "|" "|" "|" "|" "|" | tr ' ' -

                    while IFS=, read -r level class id ip hostname internal_address exposed_address; do
                        printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed_address}s|%-${longest_level}s|\n"\
                            "${id}" "${ip}" "${hostname}" "${internal_address}"\
                            "${exposed_address}" "${level}"
                    done < "${victim_tmp_file}"
                fi
                ;;
            red_team)
                if [ -n "$(cat "${red_team_tmp_file}")" ]; then
                    header_width="$((table_width-9))"
                    longest_exposed="$((longest_exposed_address+longest_level+1))"
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%b %-${header_width}s|\n" "\e[31m\e[1mRED TEAM\e[0m" " "
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                        "ID" "IP" "Hostname" "Lab internal" "Exposed at"
                    printf "%-${longest_id}s %-${longest_ip}s %-${longest_hostname}s %-${longest_internal_address}s %-${longest_exposed}s %s\n"\
                        "|" "|" "|" "|" "|" "|" | tr ' ' -

                    while IFS=, read -r level class id ip hostname internal_address exposed_address; do
                        printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                            "${id}" "${ip}" "${hostname}" "${internal_address}"\
                            "${exposed_address}"
                    done < "${red_team_tmp_file}"
                fi
                ;;
            blue_team)
                if [ -n "$(cat "${blue_team_tmp_file}")" ]; then
                    header_width="$((table_width-10))"
                    longest_exposed="$((longest_exposed_address+longest_level+1))"
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%b %-${header_width}s|\n"\
                        "\e[34m\e[1mBLUE TEAM\e[0m" " "
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                        "ID" "IP" "Hostname" "Lab internal" "Exposed at"
                    printf "%-${longest_id}s %-${longest_ip}s %-${longest_hostname}s %-${longest_internal_address}s %-${longest_exposed}s %s\n"\
                        "|" "|" "|" "|" "|" "|" | tr ' ' -

                    while IFS=, read -r level class id ip hostname internal_address exposed_address; do
                        printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                            "${id}" "${ip}" "${hostname}" "${internal_address}"\
                            "${exposed_address}"
                    done < "${blue_team_tmp_file}"
                fi
                ;;
            monitoring)
                if [ -n "$(cat "${monitoring_tmp_file}")" ]; then
                    header_width="$((table_width-11))"
                    longest_exposed="$((longest_exposed_address+longest_level+1))"
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%b %-${header_width}s|\n"\
                        "\e[35m\e[1mMONITORING\e[0m" " "
                    printf "|%-${table_width}s|\n" | tr ' ' -
                    printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                        "ID" "IP" "Hostname" "Lab internal" "Exposed at"
                    printf "%-${longest_id}s %-${longest_ip}s %-${longest_hostname}s %-${longest_internal_address}s %-${longest_exposed}s %s\n"\
                        "|" "|" "|" "|" "|" "|" | tr ' ' -

                    while IFS=, read -r level class id ip hostname internal_address exposed_address; do
                        printf "|%-${longest_id}s|%-${longest_ip}s|%-${longest_hostname}s|%-${longest_internal_address}s|%-${longest_exposed}s|\n"\
                            "${id}" "${ip}" "${hostname}" "${internal_address}"\
                            "${exposed_address}"
                    done < "${monitoring_tmp_file}"
                fi
                ;;
        esac
    done

    # Print table footer.
    printf "|%-${table_width}s|\n\n" | tr ' ' -

    _info_cleanup
}

#
# Remove tmp files.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: Nothing.
#
# Creates:
#   - Nothing
#
_info_cleanup() {
    rm "${victim_tmp_file}" "${monitoring_tmp_file}" "${red_team_tmp_file}"\
        "${blue_team_tmp_file}" "${overall_tmp_file}"
}

#
# Generate genrall lab information.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Nothing.
#   - stderr: Nothing.
#
# Creates:
#   - Global variables:
#     - lab_info: General information about lab. 
#     - services_info: General information about services. 
#
_info_buildInfo() {
    local level
    local red_team_services
    local blue_team_services
    local monitoring_services
    local services_info_file

    # Variable is defined in ../lab.sh.
    # shellcheck disable=SC2154
    services_info_file="${working_dir}/etc/services_info"

    # Info arrays to print later.
    services_info=()
    lab_info=()

    while read -r info_line; do
        services_info+=("${info_line}")
    done < "${services_info_file}"

    read -r level red_team_services blue_team_services monitoring_services\
        <<<"$(awk '{ print substr($0, index($0,$2)) }' "$HOME/.local/var/run/pentest_lab/info"\
        | tr '\n' ' ')"  

    if [ "${red_team_services}" = 'none' ]; then
        red_team_services='kali'
    elif ! [ "${red_team_services}" = 'all' ]; then
        red_team_services="kali ${red_team_services}"
    fi

    lab_info+=("- Current lab level: \e[36m${level}\e[0m")
    lab_info+=("- Red team services: \e[36m${red_team_services}\e[0m")
    lab_info+=("- Blue team services: \e[36m${blue_team_services}\e[0m")
    lab_info+=("- Monitoring services: \e[36m${monitoring_services}\e[0m")
}

#
# Print generall lab information.
#
# Arguments:
#   - None
#
# Returns:
#   - 0: Always.
#
# Prints:
#   - stdout: Lab/Service information arrays..
#   - stderr: Nothing.
#
# Creates:
#   - Nothing.
#
_info_printInfo() {
    _info_buildInfo

    # Print general information.
    printf "The lab is up and running. Have fun.\n"
    printf "To enter the lab run: '%b'\n\n"\
        "\e[36mssh root@10.5.0.5 -o \"UserKnownHostsFile /dev/null\"\e[0m"

    # Print info.
    printf "%b\n" "\e[1m\e[32mGeneral service information:\e[0m"
    printf '%s\n' "${services_info[@]}"
    printf '\n'
    
    printf "%b\n" "\e[1m\e[32mGeneral lab information:\e[0m"
    printf '%b\n' "${lab_info[@]}"
    printf '\n'

    unset services_info
    unset lab_info
}
