#!/bin/bash
# Standard colors mapped to 8-bit equivalents
ORANGE='\033[38;5;208m'
BLUE='\033[38;5;12m'
ERROR_RED='\033[38;5;9m'
LITE_GREEN='\033[38;5;10m'
NAVY_BLUE='\033[38;5;18m'
TANGERINE='\033[38;5;208m'  
GREEN='\033[38;5;2m'
SEA_GREEN='\033[38;5;74m'
FOREST_GREEN='\033[38;5;34m'
ASH_GRAY='\033[38;5;250m'
NC='\033[0m'
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)
# Constants
BUILD_TIMESTAMP=$(cat /usr/local/bin/build-timestamp.txt)

# Function to print separator line
print_separator() {
    printf "\n"
    printf "\n______________________________________________________________________________________________________________________________________________"
    printf "\n"
}

# Print ASCII art
print_ascii_art() {

    printf "${NAVY_BLUE}  /SSSSSSSS /SS /SS                  /SSSSSS                        /SS                                ${NC} \n"
    printf "${NAVY_BLUE} | SS_____/|__/| SS                 /SS__  SS                      | SS                                ${NC} \n"
    printf "${NAVY_BLUE} | SS       /SS| SS  /SSSSSS       | SS  \__/ /SS   /SS  /SSSSSSS /SSSSSS    /SSSSSS  /SSSSSS/SSSS     ${NC} \n"
    printf "${NAVY_BLUE} | SSSSS   | SS| SS /SS__  SS      |  SSSSSS | SS  | SS /SS_____/|_  SS_/   /SS__  SS| SS_  SS_  SS    ${NC} \n"
    printf "${NAVY_BLUE} | SS__/   | SS| SS| SSSSSSSS       \____  SS| SS  | SS|  SSSSSS   | SS    | SSSSSSSS| SS \ SS \ SS    ${NC} \n"
    printf "${NAVY_BLUE} | SS      | SS| SS| SS_____/       /SS  \ SS| SS  | SS \____  SS  | SS /SS| SS_____/| SS | SS | SS    ${NC} \n"
    printf "${NAVY_BLUE} | SS      | SS| SS|  SSSSSSS      |  SSSSSS/|  SSSSSSS /SSSSSSS/  |  SSSS/|  SSSSSSS| SS | SS | SS    ${NC} \n"
    printf "${NAVY_BLUE} |__/      |__/|__/ \_______/       \______/  \____  SS|_______/    \___/   \_______/|__/ |__/ |__/    ${NC} \n"
    printf "${NAVY_BLUE}                                              /SS  | SS                                                ${NC} \n"
    printf "${NAVY_BLUE}                                             |  SSSSSS/                                                ${NC} \n"
    printf "${NAVY_BLUE}                                              \______/                                                 ${NC} \n"
    printf "${NAVY_BLUE}  /SS      /SS  /SSSSSS  /SSSSSSS         /SSSSSS                                                      ${NC} \n"
    printf "${NAVY_BLUE} | SSS    /SSS /SS__  SS| SS__  SS       /SS__  SS                                                     ${NC} \n"
    printf "${NAVY_BLUE} | SSSS  /SSSS| SS  \__/| SS  \ SS      | SS  \__/  /SSSSSS   /SSSSSS  /SS    /SS /SSSSSS   /SSSSSS    ${NC} \n"
    printf "${NAVY_BLUE} | SS SS/SS SS| SS      | SSSSSSS/      |  SSSSSS  /SS__  SS /SS__  SS|  SS  /SS//SS__  SS /SS__  SS   ${NC} \n"
    printf "${NAVY_BLUE} | SS  SSS| SS| SS      | SS____/        \____  SS| SSSSSSSS| SS  \__/ \  SS/SS/| SSSSSSSS| SS  \__/   ${NC} \n"
    printf "${NAVY_BLUE} | SS\  S | SS| SS    SS| SS             /SS  \ SS| SS_____/| SS        \  SSS/ | SS_____/| SS         ${NC} \n"
    printf "${NAVY_BLUE} | SS \/  | SS|  SSSSSS/| SS            |  SSSSSS/|  SSSSSSS| SS         \  S/  |  SSSSSSS| SS         ${NC} \n"
    printf "${NAVY_BLUE} |__/     |__/ \______/ |__/             \______/  \_______/|__/          \_/    \_______/|__/         ${NC} \n"     
                                                                                                   
}

# Print Maintainer information
print_maintainer_info() {
    printf "\n"
    printf "${ORANGE} 888888ba                                      dP         dP        dP                                             dP                dP  ${NC}\n"
    printf "${ORANGE} 88     8b                                     88         88        88                                             88                88    ${NC}\n"
    printf "${ORANGE} a88aaaa8P 88d888b. .d8888b. dP    dP .d8888b. 88d888b. d8888P    d8888P .d8888b.    dp    dp .d8888b. dP    dP    88d888b. dP    dP       ${NC}\n"
    printf "${ORANGE} 88    8b. 88    88 88    88 88    88 88    88 88    88   88        88   88    88    88    88 88    88 88    88    88    88 88    88       ${NC}\n" 
    printf "${ORANGE} 88    .88 88       88.  .88 88.  .88 88.  .88 88    88   88        88   88.  .88    88.  .88 88.  .88 88.  .88    88.  .88 88.  .88 dP    ${NC}\n"
    printf "${ORANGE} 88888888P dP        88888P   88888P   8888P88 dP    dP   888P      888P  88888P      8888P88  88888P   88888P     88Y8888   8888P88 88    ${NC}\n"
    printf "${ORANGE}                                           .88                                           .88                                     .88       ${NC}\n"
    printf "${ORANGE}                                       d8888P                                        d8888P                                  d8888P        ${NC}\n"
    printf "${ASH_GRAY} ███╗   ███╗██████╗        ███╗   ███╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗██╗          █████╗ ███╗   ██╗██╗██╗  ██╗                 ${NC}\n"           
    printf "${ASH_GRAY} ████╗ ████║██╔══██╗       ████╗ ████║██╔════╝██║ ██╔╝██╔══██╗╚██╗ ██╔╝██╔════╝██║         ██╔══██╗████╗  ██║██║██║ ██╔╝                 ${NC}\n"            
    printf "${ASH_GRAY} ██╔████╔██║██║  ██║       ██╔████╔██║█████╗  █████╔╝ ███████║ ╚████╔╝ █████╗  ██║         ███████║██╔██╗ ██║██║█████╔╝                  ${NC}\n"             
    printf "${ASH_GRAY} ██║╚██╔╝██║██║  ██║       ██║╚██╔╝██║██╔══╝  ██╔═██╗ ██╔══██║  ╚██╔╝  ██╔══╝  ██║         ██╔══██║██║╚██╗██║██║██╔═██╗                  ${NC}\n"              
    printf "${ASH_GRAY} ██║ ╚═╝ ██║██████╔╝██╗    ██║ ╚═╝ ██║███████╗██║  ██╗██║  ██║   ██║   ███████╗███████╗    ██║  ██║██║ ╚████║██║██║  ██╗                 ${NC}\n"               
    printf "${ASH_GRAY} ╚═╝     ╚═╝╚═════╝ ╚═╝    ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝                 ${NC}\n"                                                                                                                                                                       
}

# Print system information
print_system_info() {
    print_separator
    
    local disp_port="$PORT"
    
    local display_ip=$(ip route | awk '/default/ {print $3}')
    
    local port_display=":$disp_port"
    [[ "$disp_port" == '80' ]] && port_display=""

printf "${GREEN} >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Starting Knowledge Graph MCP Server! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< \n${NC}"
printf "${ORANGE} ==================================${NC}\n"
printf "${ORANGE} PUID: %s${NC}\n" "${PUID:-$PGID}"
printf "${ORANGE} PGID: %s${NC}\n" "${PGID:-$PUID}"
printf "${ORANGE} MCP IP Address: %s\n${NC}" "$display_ip"
printf "${ORANGE} MCP Server PORT: ${GREEN}%s\n${NC}\n" "${disp_port:-80}"
printf "${ORANGE} ==================================${NC}\n"
printf "${ERROR_RED} Note: You may need to change the IP address to your host machine IP\n${NC}" 
[[ -f "$BUILD_TIMESTAMP" ]] && BUILD_TIMESTAMP=$(cat "$BUILD_TIMESTAMP") && printf "${ORANGE}${BUILD_TIMESTAMP}${NC}\n" 
    printf "${BLUE}This Container was started on:${NC} ${GREEN}$(date)${NC}\n"
}

# Main execution
main() {
    print_separator
    print_ascii_art
    print_maintainer_info
    print_system_info
}

main