#!/bin/bash
# YAK2 - Yet Another Kubernetes Kickstart (YAKK –> YAK2)
# Copyright (C) 2023-2024  Fabrizio de Luca
# Website: www.fdlsistemi.com

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.



# ANSI Escape Sequences: Colours and Cursor Movement - Ref. https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x329.html
lired='\033[1;31m'    # bold and light red
green='\033[1;32m'    # bold and light green
yellw='\033[1;33m'    # bold and yellow
lcyan='\033[1;36m'    # bold and light cyan
white='\033[1;37m'    # bold and white
reset='\033[0m'       # reset to system default
svcur='\033[s'        # save cursor position
recur='\033[u'        # restore cursor position
rs2nd='\033[K'        # erase to end of line
bkcol='\033[100D'     # move the cursor backward 100 columns

# Here you can optionally set the variables default values
LOG_FILE_NAME="yakk-"$(date +%Y.%m.%d-%H.%M.%S-%Z)".log"            # Deployment log file name
NODE_HOSTNAME=""                                                    # Current node hostname
NODE_DOMAIN="yourdomain.local"                                      # Current node domain
NODE_IP=""                                                          # Current node IP address
NODE_NETMASK="/24"                                                  # Current node netmask in /XX format
NODE_GATEWAY="172.20.10.2"                                          # Current node gateway IP address
NODE_DNS1="8.8.8.8"                                                 # Current node first DNS server
NODE_DNS2="8.8.4.4"                                                 # Current node second DNS server
CP_NODE_IP="172.20.10.41"                                           # Control Plane Node IP Address
CP_NODE_PWD="VMware1!VMware1!"                                      # Contorl Plane Node root password
GITHUB_API_TOKEN_VAR=""                                             # [Optional] used by lastversion to increase GitHub API rate limits – See https://github.com/settings/tokens
HELM_TIMEOUT="30m0s"                                                # A Go duration value for Helm to wait for all Pods to be in a ready state, PVCs are bound, Deployments have minimum 
                                                                    # (Desired minus maxUnavailable) Pods in ready state and Services have an IP address (and Ingress if a LoadBalancer) 
                                                                    # before marking the release as successful. If timeout is reached, the release will be marked as FAILED.
NFS_BASEPATH="/nfs-storage"                                         # Basepath of the mount point to be used (both NFS Server export and NFS Subdir Helm Chart deployment parameter)
NFS_NAMESPACE="nfs-subdir"                                          # K8S Cluster namespace to be used for deploying the NFS subdir external provisioner
NFS_IP="172.20.10.40"                                               # NFS Server IP Address
NFS_SC_NAME="nfs-client"                                            # K8S Cluster storageClass name ('nfs-client' is the NFS Subdir Project default storageClass name)
NFS_SC_DEFAULT=true                                                 # Shall this K8S Cluster storageClass be the default? (true|false)
NFS_SC_RP="Delete"                                                  # Method used to reclaim an obsoleted volume (Retain|Recycle|Delete)
NFS_SC_ARCONDEL=false                                               # Archive PVC when deleting
METALLB_REL_NAME="metallb"                                          # Helm release name for deploying MetalLB
METALLB_NAMESPACE="metallb-system"                                  # K8S Namespace for deploying MetalLB
METALLB_RANGE_FIRST_IP="172.20.10.150"                              # First IP in the Address Pool for MetalLB-backed K8S Service of type LoadBalancer
METALLB_RANGE_LAST_IP="172.20.10.199"                               # Last IP in the Address Pool for MetalLB-backed K8S Service of type LoadBalancer
METALLB_IP_POOL="metallb-ip-pool"                                   # K8S IPAddressPool name for deploying MetalLB - built as '$METALLB_RANGE_FIRST_IP-$METALLB_RANGE_LAST_IP'
METALLB_L2_ADVERT="metallb-l2-advert"                               # K8S L2Advertisement name for deploying MetalLB
KUBEAPPS_REL_NAME="kubeapps"                                        # Helm release name for deploying Kubeapps
KUBEAPPS_NAMESPACE="kubeapps"                                       # K8S Namespace for deploying Kubeapps
KUBEAPPS_SERV_ACC="kubeapps-operator"                               # K8S ServiceAccount for deploying Kubeapps
KUBEAPPS_SERV_ACC_SECRET="kubeapps-operator-token"                  # K8S Secret for deploying Kubeapps

# Function to validate IPv4 Addresses - Ref. https://www.linuxjournal.com/content/validating-ip-address-bash-script
function valid_ip()
{
  local IP2CHK=$1
  local VERDICT=1

  if [[ $IP2CHK =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    IP2CHK=($IP2CHK)
    IFS=$OIFS
    [[ ${IP2CHK[0]} -le 255 && ${IP2CHK[1]} -le 255 && ${IP2CHK[2]} -le 255 && ${IP2CHK[3]} -le 255 ]]
    VERDICT=$?
  fi
  return $VERDICT
}

# Function to log script execution
function my_logger()
{
  local CRITICALITY=$1     # INFO | WARNING | ERROR
  local MESSAGE=$2
  local OPTION=$3          # NONE | NL_PRE | NL_POST | NL_BOTH | QUIET | QUIET_NL_PRE

  if [[ $CRITICALITY = INFO ]]; then
    CRITICALITY="${green}INFO\t${reset}"
  elif [[ $CRITICALITY = WARNING ]]; then
    CRITICALITY="${yellw}WARNING\t${reset}"
  elif [[ $CRITICALITY = ERROR ]]; then
    CRITICALITY="${lired}ERROR\t${reset}"
  fi

  if [[ $OPTION = NONE ]]; then
    echo -e " "$CRITICALITY - $MESSAGE && echo -e $(date -Ins -u) - $CRITICALITY - $MESSAGE >> $LOG_FILE_NAME
  elif [[ $OPTION = NL_PRE ]]; then
    echo -e "\n "$CRITICALITY - $MESSAGE && echo -e "\n"$(date -Ins -u) - $CRITICALITY - $MESSAGE >> $LOG_FILE_NAME
  elif [[ $OPTION = NL_POST ]]; then
    echo -e " "$CRITICALITY - $MESSAGE "\n" && echo -e $(date -Ins -u) - $CRITICALITY - $MESSAGE "\n" >> $LOG_FILE_NAME
  elif [[ $OPTION = NL_BOTH ]]; then
    echo -e "\n "$CRITICALITY - $MESSAGE "\n" && echo -e "\n"$(date -Ins -u) - $CRITICALITY - $MESSAGE "\n" >> $LOG_FILE_NAME
  elif [[ $OPTION = QUIET ]]; then
    echo -e $(date -Ins -u) - $CRITICALITY - $MESSAGE >> $LOG_FILE_NAME
  elif [[ $OPTION = QUIET_NL_PRE ]]; then
    echo -e "\n"$(date -Ins -u) - $CRITICALITY - $MESSAGE >> $LOG_FILE_NAME
  fi
}

# Function to fetch and display (decr sorting) all available builds for a given software package
function custom_sw_builds()
{
  local PKG_NAME=$1
  local PKG_URL=$2
  declare -n OUTPUT=$3
  
  echo -e "${yellw}---- Available $PKG_NAME Versions ----${reset}"
  readarray -t ALT_VERS < <( lastversion -v $PKG_URL 2>&1 | grep "Parsed as Version OK" | cut -b 81- | sed 's/\(.*\)./\1/' | sort -Vr | uniq )
  for ((i = 0; i < ${#ALT_VERS[@]}; i++)); do echo -e " ${i}. ${white}${ALT_VERS[$i]}${reset}"; done
  while [[ true ]]; do
    echo -en "${green}Select the version you want to deploy [ ${white}0 - $((${#ALT_VERS[@]} - 1)) || Enter = ${ALT_VERS[0]}${green} ]: ${svcur}${white}${rs2nd}"; read -p '' IDX; if [[ -z $IDX ]]; then IDX=0; fi;
    if [[ ! $IDX =~ ^[0-$((${#ALT_VERS[@]} - 1))]$ ]]; then echo -en "${recur}${lired}NOT A VALID SELECTION!${bkcol}"; sleep 1; else break; fi;
  done
  OUTPUT=${ALT_VERS[$IDX]}
}

# This is a base64-encoded banner created with FIGlet: a program that creates large characters out of ordinary screen characters - Ref. https://github.com/cmatsuoka/figlet
BANNER=CgoKCgoKCgoKCiAgICAgICAgICAgICAgICAgICBfXyAgIF9fICAgXyAgICAgICAgIF8gICAgICAgICAgICAgICAgXyAgIF8gICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgIFwgXCAvIC9fX3wgfF8gICAgICAvIFwgICBfIF9fICAgX19fIHwgfF98IHxfXyAgIF9fXyBfIF9fIAogICAgICAgICAgICAgICAgICAgIFwgViAvIF8gXCBfX3wgICAgLyBfIFwgfCAnXyBcIC8gXyBcfCBfX3wgJ18gXCAvIF8gXCAnX198CiAgICAgICAgICAgICAgICAgICAgIHwgfCAgX18vIHxfICAgIC8gX19fIFx8IHwgfCB8IChfKSB8IHxffCB8IHwgfCAgX18vIHwgICAKICAgICAgICAgICAgICAgICAgICAgfF98XF9fX3xcX18vICAvXy8gICBcX1xffCB8X3xcX19fLyBcX198X3wgfF98XF9fX3xffCAgIAoKICAgIF8gIF9fICAgICBfICAgICAgICAgICAgICAgICAgICAgICAgICBfICAgICAgICAgICAgICAgXyAgX19fICAgICAgXyAgICAgICAgXyAgICAgICAgICAgICBfICAgCiAgIHwgfC8gLyAgIF98IHxfXyAgIF9fXyBfIF9fIF8gX18gICBfX198IHxfIF9fXyAgX19fICAgfCB8LyAoXykgX19ffCB8IF9fX19ffCB8XyBfXyBfIF8gX198IHxfIAogICB8ICcgLyB8IHwgfCAnXyBcIC8gXyBcICdfX3wgJ18gXCAvIF8gXCBfXy8gXyBcLyBfX3wgIHwgJyAvfCB8LyBfX3wgfC8gLyBfX3wgX18vIF9gIHwgJ19ffCBfX3wKICAgfCAuIFwgfF98IHwgfF8pIHwgIF9fLyB8ICB8IHwgfCB8ICBfXy8gfHwgIF9fL1xfXyBcICB8IC4gXHwgfCAoX198ICAgPFxfXyBcIHx8IChffCB8IHwgIHwgfF8gCiAgIHxffFxfXF9fLF98Xy5fXy8gXF9fX3xffCAgfF98IHxffFxfX198XF9fXF9fX3x8X19fLyAgfF98XF9cX3xcX19ffF98XF9cX19fL1xfX1xfXyxffF98ICAgXF9ffAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKCiAgIEF1dGhvcjogRmFicml6aW8gZGUgTHVjYQogICBXZWJzaXRlOiB3d3cuZmRsc2lzdGVtaS5jb20K
clear; echo -e "${green}"; echo $BANNER | base64 --decode | tee -a $LOG_FILE_NAME; echo -e "${reset}"; sleep 2


clear

echo -e "\n" >> $LOG_FILE_NAME
my_logger INFO "Launching Kubernetes Cluster deployment script." QUIET
test -f ~/.bash_login && rm ~/.bash_login     # Disables script autostart at login


echo -e "${green}################################################################################################### ${reset}"
echo -e "${white} NETWORK CONFIGURATION AND PREREQUISITES INSTALLATION                                     # START # ${reset}\n"

echo -e "${yellw}---- Node Configuration (press ENTER to accept the dafault, if any) ----"
while [[ true ]]; do
  echo -en "${green}Hostname [${white}$NODE_HOSTNAME${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_HOSTNAME=$TMP; fi;
  if [[ -z $NODE_HOSTNAME ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; else break; fi;
done
while [[ true ]]; do
  echo -en "${green}Domain [${white}$NODE_DOMAIN${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_DOMAIN=$TMP; fi;
  if [[ -z $NODE_DOMAIN ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; else break; fi;
done
while [[ true ]]; do
  echo -en "${green}IP Address [${white}$NODE_IP${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_IP=$TMP; fi;
  if [[ -z $NODE_IP ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; 
  elif [[ ! -z $NODE_IP ]] && valid_ip $NODE_IP; then break; 
  else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; NODE_IP=""; sleep 1; 
  fi;
done
while [[ true ]]; do
  echo -en "${green}Netmask (/XX) [${white}$NODE_NETMASK${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_NETMASK=$TMP; fi;
  if [[ -z $NODE_NETMASK ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1;
  elif [[ ! -z $NODE_NETMASK ]] && [[ $NODE_NETMASK =~ ^(\/([0-9]|[1-2][0-9]|3[0-2]))?$ ]] ; then break;
  else echo -en "${recur}${lired}NOT A VALID NETMASK IN /XX FORMAT!${bkcol}"; NODE_NETMASK=""; sleep 1; 
  fi;
done
while [[ true ]]; do
  echo -en "${green}Gateway [${white}$NODE_GATEWAY${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_GATEWAY=$TMP; fi;
  if [[ -z $NODE_GATEWAY ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; 
  elif [[ ! -z $NODE_GATEWAY ]] && valid_ip $NODE_GATEWAY; then break; 
  else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; NODE_GATEWAY=""; sleep 1; 
  fi;
done
while [[ true ]]; do
  echo -en "${green}DNS1 [${white}$NODE_DNS1${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_DNS1=$TMP; fi;
  if [[ -z $NODE_DNS1 ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1;
  elif [[ ! -z $NODE_DNS1 ]] && valid_ip $NODE_DNS1; then break; 
  else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; NODE_DNS1=""; sleep 1; 
  fi;
done
while [[ true ]]; do
  echo -en "${green}DNS2 [${white}$NODE_DNS2${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then NODE_DNS2=$TMP; fi;
  if [[ ! -z $NODE_DNS2 ]] && valid_ip $NODE_DNS2; then break; 
  elif [[ ! -z $NODE_DNS2 ]]; then echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; NODE_DNS2=""; sleep 1;
  else break;
  fi;
done
# recommended for lastversion utility to increase GitHub API rate limits - Ref. https://github.com/dvershinin/lastversion#tips
echo -en "${green}GitHub API token [${white}$GITHUB_API_TOKEN_VAR${green}]: ${white}"; read -p '' TMP; if [ ! -z $TMP ]; then GITHUB_API_TOKEN_VAR=$TMP; fi;

my_logger INFO "USER INPUT - Collected Node Configuration Parameters:\n
 - Hostname:...........$NODE_HOSTNAME\n
 - Domain:.............$NODE_DOMAIN\n
 - IP Address:.........$NODE_IP\n
 - Netmask:............$NODE_NETMASK\n
 - Gateway:............$NODE_GATEWAY\n
 - DNS1:...............$NODE_DNS1\n
 - DNS2:...............$NODE_DNS2\n
 - GITHUB API TOKEN:...$GITHUB_API_TOKEN_VAR\n" QUIET

hostnamectl set-hostname $NODE_HOSTNAME.$NODE_DOMAIN
my_logger INFO "Configured Node Hostname as: $(hostnamectl hostname) - [from: hostnamectl]." QUIET

cat <<EOF > /etc/systemd/network/10-static-en.network
[Match]
Name=e*

[Network]
Address=$NODE_IP$NODE_NETMASK
Gateway=$NODE_GATEWAY
DNS=$NODE_DNS1 $NODE_DNS2
LinkLocalAddressing=no
IPv6AcceptRA=no
EOF
chmod 644 /etc/systemd/network/10-static-en.network
if [ $([ -s /etc/systemd/network/10-static-en.network ]; echo $?) == 0 ]; then
  my_logger INFO "Successfully wrote NIC config file /etc/systemd/network/10-static-en.network" QUIET
else
  my_logger ERROR "Failed writing NIC config file /etc/systemd/network/10-static-en.network" QUIET
fi

test -f /etc/systemd/network/99-dhcp-en.network && rm /etc/systemd/network/99-dhcp-en.network

echo -e "" >> /etc/hosts
echo -e "---" >> /etc/hosts
echo -e "" >> /etc/hosts
echo -e "# Begin Kubernetes nodes list" >> /etc/hosts
echo -e "" >> /etc/hosts
echo -e "${NODE_IP}\t${NODE_HOSTNAME}.${NODE_DOMAIN}\t${NODE_HOSTNAME}" >> /etc/hosts
echo -e "# End Kubernetes nodes list" >> /etc/hosts >> /etc/hosts

my_logger INFO "Restarting the systemd-networkd service." QUIET
systemctl restart systemd-networkd
systemctl status systemd-networkd --no-pager >> $LOG_FILE_NAME

while [[ true ]]; do
  if [[ ! -z $(ip a show eth0 | grep -v inet6 | grep inet) ]]; then break; fi;
  sleep 1;
done
my_logger INFO "Configured Node NIC as: $(ip a show eth0 | grep inet) - [from: ip address]." QUIET_NL_PRE
my_logger INFO "Configured Node Gateway as: $(netstat -rn | grep -E 'G.*eth0') - [from: netstat -rn]." QUIET
my_logger INFO "Configured Node DNS server(s) as: $(cat /run/systemd/resolve/resolv.conf | grep nameserver) - [from: /run/systemd/resolve/resolv.conf]." QUIET
my_logger INFO "Configured Node into local hosts file as: $(cat /etc/hosts | grep $NODE_IP) - [from: /etc/hosts]." QUIET

my_logger INFO "Installing package nmap-ncat: ncat is a feature packed networking utility which will read and write data across a network from the command line." NL_PRE
tdnf -y install nmap-ncat >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

my_logger INFO "Installing package sshpass: noninteractive ssh password provider." NL_PRE
tdnf -y install sshpass >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

echo -e "\n${white}                                                                                            # END # "
echo -e "${green}################################################################################################### ${reset}"


clear


echo -e "${green}################################################################################################### ${reset}"
echo -e "${white} CONFIGURATION OPTIONS (1/2)                                                              # START # ${reset}\n"

echo -e "${yellw}---- Chose a Deployment Type ----${reset}"
NODE_TYPES=("Control Plane Node" "Worker Node" "NFS Server")
while true; do
  select NODE_TYPE in "${NODE_TYPES[@]}"
  do
    case $REPLY in
      1) echo -e "You are going to configure a ${green}$NODE_TYPE${reset}"; break 2;;
      2) echo -e "You are going to configure a ${green}$NODE_TYPE${reset}"; break 2;;
      3) echo -e "You are going to configure a ${green}$NODE_TYPE${reset}"; break 2;;
      *) echo -e "\r"; break;
    esac
  done
done
my_logger INFO "USER INPUT - Selected Deployment Type: $NODE_TYPE." QUIET

if [ $REPLY != 3 ]; then     # If NFS Server then skip
  echo -e "\n"
  my_logger INFO "Installing package wget: a network utility to retrieve files from the Web." NONE
  tdnf -y install wget >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
fi

if [ $REPLY = 1 ]; then     # Control Plane node
  my_logger INFO "Installing package pip: the Package Installer for Python." NONE
  wget https://bootstrap.pypa.io/get-pip.py -a $LOG_FILE_NAME --no-verbose --show-progress; echo "" >> $LOG_FILE_NAME
  
  # 2024.03.17: FIX for an apparently forgotten and empty folder in Python 3.11 which causes "python setup.py egg_info" - part of pip installation process - to fail with message "UserWarning: Unknown distribution option 'test_suite'"
  DIR="/usr/lib/python3.11/site-packages/setuptools-65.5.0.dist-info"
  if [ -d "$DIR" ]; then
    if [ -z "$(ls -A $DIR)" ]; then
       rmdir $DIR
       my_logger INFO "Folder $DIR was FOUND EMPTY; hence, it has been removed to avoid <<python setup.py egg_info>> - part of pip installation process - to fail with message: <<UserWarning: Unknown distribution option 'test_suite'>>." QUIET
    else
       my_logger INFO "Folder $DIR was FOUND NOT EMPTY; hence, no action has been taken (see yakk.sh script)." QUIET
    fi
  else
    my_logger INFO "Folder $DIR was NOT FOUND; hence, no action has been taken (see yakk.sh script)." QUIET
  fi
  # END FIX

  python get-pip.py --root-user-action=ignore >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Installing package lastversion: a tiny command line utility to retrieve the latest stable version of a GitHub project. - Ref. https://github.com/dvershinin/lastversion" NONE
  pip install lastversion --root-user-action=ignore >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  echo "export GITHUB_API_TOKEN="$GITHUB_API_TOKEN_VAR >> ~/.bashrc
  source ~/.bashrc
  if [[ ! $(cat ~/.bashrc | grep $GITHUB_API_TOKEN_VAR) ]] then
    my_logger WARNING "GITHUB_API_TOKEN not set in ~/.bashrc file. A GITHUB_API_TOKEN for lastversion utility is recommended to increase GitHub API rate limits. - Ref. https://github.com/dvershinin/lastversion#tips" QUIET
  elif [[ $(cat ~/.bashrc | grep $GITHUB_API_TOKEN_VAR) ]] && [[ ! $(printenv | grep $GITHUB_API_TOKEN_VAR) ]]; then
    my_logger WARNING "GITHUB_API_TOKEN not sourced into current shell environment. A GITHUB_API_TOKEN for lastversion utility is recommended to increase GitHub API rate limits. - Ref. https://github.com/dvershinin/lastversion#tips" QUIET
  elif [[ $(cat ~/.bashrc | grep $GITHUB_API_TOKEN_VAR) ]] && [[ $(printenv | grep $GITHUB_API_TOKEN_VAR) ]]; then 
    my_logger INFO "GITHUB_API_TOKEN found in ~/.bashrc file and successfully sourced into current shell environment." QUIET
  fi
fi

if [ $REPLY = 2 ] || [ $REPLY = 3 ]; then     # Worker nodes or NFS Server
  echo -e "\n"
  while [[ true ]]; do
    echo -en "${green}Control Plane Node IP Address [${white}$CP_NODE_IP${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then CP_NODE_IP=$TMP; fi;
    if [[ -z $CP_NODE_IP ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; 
    elif [[ ! -z $CP_NODE_IP ]] && valid_ip $CP_NODE_IP; then break; 
    else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; CP_NODE_IP=""; sleep 1; 
    fi;
  done
  my_logger INFO "USER INPUT - Control Plane Node IP Address: $CP_NODE_IP." QUIET

  while [[ true ]]; do
    echo -en "${green}Control Plane Node Password [${white}$CP_NODE_PWD${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then CP_NODE_PWD=$TMP; fi;
    if [[ -z $CP_NODE_PWD ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; else break; fi;
  done
  my_logger INFO "USER INPUT - Control Plane Node IP Password: $CP_NODE_PWD." QUIET
  echo $CP_NODE_PWD >> .params

  echo -e "\n"
  while ! ncat -vz $CP_NODE_IP 22 > /dev/null 2>&1; do
    my_logger INFO "Waiting for the remote Control Plane Node to start listening at $CP_NODE_IP:22..." NONE
    sleep 10
  done

  # Checks whether an entry the local node already exists in the Control Plane /etc/hosts file. This control is made to avoid duplicate entries in case of a node re-deploy.
  if [[ -z $(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'cat /etc/hosts | grep "'$NODE_IP'" | grep "'$NODE_HOSTNAME'"."'$NODE_DOMAIN'" | grep "'$NODE_HOSTNAME'"') ]]; then
    # Replaces the local /etc/hosts file with the Control Plane one (which includes all the already existing K8S nodes) and appends the soon-to-be-added worker node details (IP, FQDN, Hostname)
    rm /etc/hosts
    sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'sed "/^# End Kubernetes nodes list.*/i "'$NODE_IP'"\t"'$NODE_HOSTNAME'"."'$NODE_DOMAIN'"\t"'$NODE_HOSTNAME'"" /etc/hosts' >> /etc/hosts
    my_logger INFO "Fetched a copy of the Control Plane Node /etc/hosts file, which includes all currently known K8S Nodes, and re-added local Node details." QUIET
    cat /etc/hosts >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

    # Loads into an array all the K8S nodes IP addresses from the local /etc/hosts file and removes the local IP address
    readarray -t K8S_NODES < <(sed -n '/# Begin Kubernetes/,1000p' /etc/hosts | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    K8S_NODES=( "${K8S_NODES[@]/$NODE_IP}" )
    my_logger INFO "Retrieved a list of K8S Nodes that need to be updated adding this Node details to their /etc/hosts file(s):$(for K8S_NODE in ${K8S_NODES[@]}; do echo -e "\n - $K8S_NODE"; done)." QUIET

    # Updates all other K8S nodes /etc/hosts files by appending the soon-to-be-added worker node details (IP, FQDN, Hostname)
    for K8S_NODE in ${K8S_NODES[@]}; do
      sshpass -f .params ssh -o StrictHostKeyChecking=no root@$K8S_NODE 'sed -i "/^# End Kubernetes nodes list.*/i "'$NODE_IP'"\t"'$NODE_HOSTNAME'"."'$NODE_DOMAIN'"\t"'$NODE_HOSTNAME'"" /etc/hosts' >> /etc/hosts
      if [[ $(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$K8S_NODE cat /etc/hosts | grep $NODE_IP) ]]; then
        my_logger INFO "Successfully added local Node as [$NODE_IP - $NODE_HOSTNAME.$NODE_DOMAIN - $NODE_HOSTNAME] to remote Node $K8S_NODE:/etc/hosts file." QUIET
      else
        my_logger ERROR "Failed adding local Node as [$NODE_IP - $NODE_HOSTNAME.$NODE_DOMAIN - $NODE_HOSTNAME] to remote Node $K8S_NODE:/etc/hosts file." QUIET
      fi
    done
  fi
fi


clear


if [ $REPLY = 1 ]; then     # Control Plane node
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} CONFIGURATION OPTIONS (2/2 - CONTROL PLANE NODE)                                         # START # ${reset}\n"

  echo -e "${yellw}---- Default Software Versions Configuration ----${reset}"
  VER_CONTAINERD=$(lastversion https://github.com/containerd/containerd)
  echo -e " - Latest ${green}containerd${reset} version:  ${white}$VER_CONTAINERD${reset}"
  VER_RUNC=$(lastversion https://github.com/opencontainers/runc)
  echo -e " - Latest ${green}runc${reset} version:        ${white}$VER_RUNC${reset}"
  VER_PLUGINS=$(lastversion https://github.com/containernetworking/plugins)
  echo -e " - Latest ${green}CNI plugins${reset} version: ${white}$VER_PLUGINS${reset}"
  VER_K8S=$(lastversion https://github.com/kubernetes/kubernetes)
  echo -e " - Latest ${green}Kubernetes${reset} version:  ${white}$VER_K8S${reset}"
  VER_ANTREA=$(lastversion https://github.com/antrea-io/antrea)
  echo -e " - Latest ${green}Antrea${reset} version:      ${white}$VER_ANTREA${reset}"
  VER_SUBDIR=$(lastversion https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
  echo -e " - Latest ${green}NFS subdir${reset} version:  ${white}$VER_SUBDIR${reset}"
  VER_METALLB=$(lastversion https://github.com/metallb/metallb)
  echo -e " - Latest ${green}MetalLB${reset} version:     ${white}$VER_METALLB${reset}"
  VER_KUBEAPPS=$(lastversion https://github.com/kubeapps/kubeapps)
  echo -e " - Latest ${green}Kubeapps${reset} version:    ${white}$VER_KUBEAPPS${reset}"

  echo -e "\n"
  while true; do
    echo -e "${green}"; read -p "Do you want to install different software verions? [y/N] " CHANGE_VER; echo -e "${reset}";
    case $CHANGE_VER in
      [nN] | "" ) break;;
      [yY] ) break;;
      * ) echo -e "${lired}NOT A VALID ANSWER!${reset}";;
    esac
  done

  if [[ $CHANGE_VER = y ]] || [[ $CHANGE_VER = Y ]]; then
    custom_sw_builds "containerd" https://github.com/containerd/containerd VER_CONTAINERD
    echo -e "\n"
    custom_sw_builds "runc" https://github.com/opencontainers/runc VER_RUNC
    echo -e "\n"
    custom_sw_builds "CNI plugins" https://github.com/containernetworking/plugins VER_PLUGINS
    echo -e "\n"
    custom_sw_builds "Kubernetes" https://github.com/kubernetes/kubernetes VER_K8S
    echo -e "\n"
    custom_sw_builds "Antrea" https://github.com/antrea-io/antrea VER_ANTREA
    echo -e "\n"
    custom_sw_builds "NFS subdir" https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner VER_SUBDIR
    echo -e "\n"
    custom_sw_builds "MetalLB" https://github.com/metallb/metallb VER_METALLB
    echo -e "\n"
    # TO DO: at the moment Kubeapps lastversion doesn't match it Helm Chart version; hence, versioned deployment doesn't work.
    custom_sw_builds "Kubeapps" https://github.com/kubeapps/kubeapps VER_KUBEAPPS
    echo -e "\n"
  fi

  echo -e "${yellw}---- Final Software Versions Selection ----${reset}"
  echo -e " - Selected ${green}containerd${reset} version:  ${white}$VER_CONTAINERD${reset}" && my_logger INFO "USER INPUT - Selected Package: containerd $VER_CONTAINERD" QUIET
  echo -e " - Selected ${green}runc${reset} version:        ${white}$VER_RUNC${reset}"       && my_logger INFO "USER INPUT - Selected Package: runc $VER_RUNC" QUIET
  echo -e " - Selected ${green}CNI plugins${reset} version: ${white}$VER_PLUGINS${reset}"    && my_logger INFO "USER INPUT - Selected Package: cniplugins $VER_PLUGINS" QUIET
  echo -e " - Selected ${green}Kubernetes${reset} version:  ${white}$VER_K8S${reset}"        && my_logger INFO "USER INPUT - Selected Package: kubernetes $VER_K8S" QUIET
  echo -e " - Selected ${green}Antrea${reset} version:      ${white}$VER_ANTREA${reset}"     && my_logger INFO "USER INPUT - Selected Package: antrea $VER_ANTREA" QUIET
  echo -e " - Selected ${green}NFS subdir${reset} version:  ${white}$VER_SUBDIR${reset}"     && my_logger INFO "USER INPUT - Selected Package: subdir $VER_SUBDIR" QUIET
  echo -e " - Selected ${green}MetalLB${reset} version:     ${white}$VER_METALLB${reset}"    && my_logger INFO "USER INPUT - Selected Package: metallb $VER_METALLB" QUIET
  echo -e " - Selected ${green}Kubeapps${reset} version:    ${white}$VER_KUBEAPPS${reset}"   && my_logger INFO "USER INPUT - Selected Package: kubeapps $VER_KUBEAPPS" QUIET

  echo -e "\n${green}MetalLB LoadBalancer External IP Range:${reset}"
  while [[ true ]]; do
    echo -en "${green} - First IP [${white}$METALLB_RANGE_FIRST_IP${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then METALLB_RANGE_FIRST_IP=$TMP; fi;
    if [[ -z $METALLB_RANGE_FIRST_IP ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; 
    elif [[ ! -z $METALLB_RANGE_FIRST_IP ]] && valid_ip $METALLB_RANGE_FIRST_IP; then break; 
    else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; METALLB_RANGE_FIRST_IP=""; sleep 1; 
    fi;
  done
  while [[ true ]]; do
    echo -en "${green} - Last IP [${white}$METALLB_RANGE_LAST_IP${green}]: ${svcur}${white}${rs2nd}"; read -p '' TMP; if [ ! -z $TMP ]; then METALLB_RANGE_LAST_IP=$TMP; fi;
    if [[ -z $METALLB_RANGE_LAST_IP ]]; then echo -en "${recur}${lired}VALUE CANNOT BE EMPTY!${bkcol}"; sleep 1; 
    elif [[ ! -z $METALLB_RANGE_LAST_IP ]] && valid_ip $METALLB_RANGE_LAST_IP; then break; 
    else echo -en "${recur}${lired}NOT A VALID IP ADDRESS!${bkcol}"; METALLB_RANGE_LAST_IP=""; sleep 1; 
    fi;
  done
  my_logger INFO "USER INPUT - Provided MetalLB LoadBalancer External IP Range: $METALLB_RANGE_FIRST_IP - $METALLB_RANGE_LAST_IP." QUIET
fi

if [ $REPLY = 2 ]; then    # Worker nodes
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} CONFIGURATION OPTIONS (2/2 - WORKER NODES - PREFLIGHT)                                   # START # ${reset}\n"

  REMOTE_LOG_FILE_NAME=$(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'ls yakk-*')
  while [[ $(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'cat "'$REMOTE_LOG_FILE_NAME'" | grep "USER INPUT - Selected Package:" | wc -l') != 8 ]]; do
    my_logger INFO "Waiting for the remote Control Plane Node to log the Final Software Versions Selection..." NONE
    sleep 10
  done

  
  clear


  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} CONFIGURATION OPTIONS (2/2 - WORKER NODES - FETCH CONFIGURATION)                         # START # ${reset}\n"

  # Locates the desidered Control Plane Node log entries identified by a string, then rips off the timestamp and the string used by grep (that is, first 89 chars).
  # Next, identifies 2 fileds in the remaing text - havinng a space char as a field separator - and keeps the 2nd field only, that is the selected version of each software package.
  # Last, it loads the retrieved Final Software Versions Selection into an array.
  readarray -t CONF_VERS < <( sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'cat "'$REMOTE_LOG_FILE_NAME'" | grep "USER INPUT - Selected Package:"| cut -b 89- | cut -d " " -f 2' )
  echo -e "${yellw}---- Retrieved Software Versions Selection ----${reset}"
  VER_CONTAINERD=${CONF_VERS[0]}; echo -e " - Retrieved ${green}containerd${reset} version:  ${white}$VER_CONTAINERD${reset}" && my_logger INFO "CONTROL PLANE - Retrieved Package: containerd $VER_CONTAINERD" QUIET
  VER_RUNC=${CONF_VERS[1]};       echo -e " - Retrieved ${green}runc${reset} version:        ${white}$VER_RUNC${reset}"       && my_logger INFO "CONTROL PLANE - Retrieved Package: runc $VER_RUNC" QUIET
  VER_PLUGINS=${CONF_VERS[2]};    echo -e " - Retrieved ${green}CNI plugins${reset} version: ${white}$VER_PLUGINS${reset}"    && my_logger INFO "CONTROL PLANE - Retrieved Package: cniplugins $VER_PLUGINS" QUIET
  VER_K8S=${CONF_VERS[3]};        echo -e " - Retrieved ${green}Kubernetes${reset} version:  ${white}$VER_K8S${reset}"        && my_logger INFO "CONTROL PLANE - Retrieved Package: kubernetes $VER_K8S" QUIET
  VER_ANTREA=${CONF_VERS[4]};     echo -e " - Retrieved ${green}Antrea${reset} version:      ${white}$VER_ANTREA${reset}"     && my_logger INFO "CONTROL PLANE - Retrieved Package: antrea $VER_ANTREA" QUIET
  VER_SUBDIR=${CONF_VERS[5]};     echo -e " - Retrieved ${green}NFS subdir${reset} version:  ${white}$VER_SUBDIR${reset}"     && my_logger INFO "CONTROL PLANE - Retrieved Package: subdir $VER_SUBDIR" QUIET
  VER_METALLB=${CONF_VERS[6]};    echo -e " - Retrieved ${green}MetalLB${reset} version:     ${white}$VER_METALLB${reset}"    && my_logger INFO "CONTROL PLANE - Retrieved Package: metallb $VER_METALLB" QUIET
  VER_KUBEAPPS=${CONF_VERS[7]};   echo -e " - Retrieved ${green}Kubeapps${reset} version:    ${white}$VER_KUBEAPPS${reset}"   && my_logger INFO "CONTROL PLANE - Retrieved Package: kubeapps $VER_KUBEAPPS" QUIET
  sleep 2
fi

echo -e "\n${white}                                                                                            # END # "
echo -e "${green}################################################################################################### ${reset}"


clear


echo -e "${green}################################################################################################### ${reset}"
echo -e "${white} IPTABLES CONFIGURATION                                                                   # START # ${reset}\n"

if [ $REPLY = 1 ]; then     # Control Plane node
  iptables -A INPUT -p tcp --dport 6443 -j ACCEPT            # Kubernetes API server
  iptables -A INPUT -p tcp --dport 2379:2380 -j ACCEPT       # etcd server client API
  iptables -A INPUT -p tcp --dport 10250 -j ACCEPT           # Kubelet API
  iptables -A INPUT -p tcp --dport 10259 -j ACCEPT           # kube-scheduler
  iptables -A INPUT -p tcp --dport 10257 -j ACCEPT           # kube-controller-manager
  iptables -A INPUT -p tcp --dport 10349:10351 -j ACCEPT     # Antrea
  iptables -A INPUT -p udp --dport 10351 -j ACCEPT           # Antrea
  iptables -A INPUT -p tcp --dport 7946 -j ACCEPT            # MetalLB in L2 operating mode
  iptables -A INPUT -p udp --dport 7946 -j ACCEPT            # MetalLB in L2 operating mode
elif [ $REPLY = 2 ]; then     # Worker nodes
  iptables -A INPUT -p tcp --dport 10250 -j ACCEPT           # Kubelet API
  iptables -A INPUT -p tcp --dport 30000:32767 -j ACCEPT     # NodePort Services
  iptables -A INPUT -p tcp --dport 10349:10351 -j ACCEPT     # Antrea
  iptables -A INPUT -p udp --dport 10351 -j ACCEPT           # Antrea
  iptables -A INPUT -p tcp --dport 7946 -j ACCEPT            # MetalLB in L2 operating mode
  iptables -A INPUT -p udp --dport 7946 -j ACCEPT            # MetalLB in L2 operating mode
elif [ $REPLY = 3 ]; then     # NFS Server
  iptables -A INPUT -p tcp --dport 2049 -j ACCEPT            # NFS Server
fi
iptables-save > /etc/systemd/scripts/ip4save

my_logger WARNING "Currently kubelet seems to fail in writing rules to iptables, making all Pods and Services unreachable. TEMPORARILY DISABLING IPTABLES AS A (DESPERATE) WORKAROUND." NONE
my_logger INFO "Disabling the iptables service." NL_PRE
# systemctl restart iptables
# iptables -L
systemctl stop iptables
systemctl disable iptables
systemctl status iptables --no-pager >> $LOG_FILE_NAME
echo "" >> $LOG_FILE_NAME
sleep 2

echo -e "\n${white}                                                                                            # END # "
echo -e "${green}################################################################################################### ${reset}"


clear


if [ $REPLY != 3 ]; then     # If NFS Server then skip CONTAINERD, RUNC AND CNI NETWORK PLUGINS INSTALLATION 
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} CONTAINERD, RUNC AND CNI NETWORK PLUGINS INSTALLATION                                    # START # ${reset}\n"

  my_logger INFO "Removing PhotonOS distro-specific versions of docker, docker-engine and runc." QUIET_NL_PRE
  tdnf -y remove docker docker-engine runc | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Installing package tar: archiving program." NL_PRE
  tdnf -y install tar | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Installing package containerd $VER_CONTAINERD: an industry-standard container runtime with an emphasis on simplicity, robustness, and portability. - Ref. https://containerd.io" NL_PRE
  wget https://github.com/containerd/containerd/releases/download/v${VER_CONTAINERD}/containerd-${VER_CONTAINERD}-linux-amd64.tar.gz -a $LOG_FILE_NAME --no-verbose --show-progress; echo "" >> $LOG_FILE_NAME
  tar Cxzvf /usr/local containerd-${VER_CONTAINERD}-linux-amd64.tar.gz | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
  mkdir -p /usr/local/lib/systemd/system/
  wget --output-document=/usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -a $LOG_FILE_NAME --no-verbose --show-progress; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Reloading the systemd unit files." QUIET
  systemctl daemon-reload

  my_logger INFO "Enabling the containerd service." QUIET
  systemctl enable --now containerd
  systemctl status containerd --no-pager >> $LOG_FILE_NAME

  my_logger INFO "Installing package runc $VER_RUNC: a CLI tool for spawning and running containers on Linux according to the OCI specification. - Ref. https://github.com/opencontainers/runc" NL_PRE
  wget https://github.com/opencontainers/runc/releases/download/v${VER_RUNC}/runc.amd64 -a $LOG_FILE_NAME --no-verbose --show-progress; echo "" >> $LOG_FILE_NAME
  install -m 755 runc.amd64 /usr/local/bin/runc | tee -a $LOG_FILE_NAME

  my_logger INFO "Installing package CNI network plugins $VER_PLUGINS: maintained by the containernetworking team. - Ref. https://github.com/containernetworking/plugins/" NL_PRE
  wget https://github.com/containernetworking/plugins/releases/download/v${VER_PLUGINS}/cni-plugins-linux-amd64-v${VER_PLUGINS}.tgz -a $LOG_FILE_NAME --no-verbose --show-progress; echo "" >> $LOG_FILE_NAME
  mkdir -p /opt/cni/bin
  tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v${VER_PLUGINS}.tgz | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Trying to find which version of the pause container image is required by Kubernetes $VER_K8S." NL_PRE
  VER_K8S_MAJOR_MINOR=$(echo $VER_K8S | grep -Eo '[0-9]\.[0-9]+')
  VER_PAUSE=$(curl -s https://raw.githubusercontent.com/kubernetes/kubernetes/release-${VER_K8S_MAJOR_MINOR}/build/pause/Makefile | grep "TAG ?="  | awk '{print $3}')
  if [[ ! -z VER_PAUSE ]]; then
    my_logger INFO " - Kubernetes $VER_K8S requires ${green}pause${reset} version: ${white}$VER_PAUSE${reset}" NL_POST
    VER_PAUSE_TOML='sandbox_image = "registry.k8s.io/pause:'$VER_PAUSE'"'
  else
    my_logger WARNING "Unable to fetch a Kubernetes-recommended [TAG ?= X.XX] CRI sandbox image from https://raw.githubusercontent.com/kubernetes/kubernetes/release-${VER_K8S_MAJOR_MINOR}/build/pause/Makefile. Using containerd default." NL_POST
  fi

cat <<EOF | tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    $VER_PAUSE_TOML
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

  if [ $([ -s /etc/containerd/config.toml ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully wrote parameters to containerd config file /etc/containerd/config.toml" QUIET
  else
    my_logger ERROR "Failed writing parameters to containerd config file /etc/containerd/config.toml" QUIET
  fi

  my_logger INFO "Restarting the containerd service." QUIET
  systemctl restart containerd
  systemctl status containerd.service --no-pager >> $LOG_FILE_NAME

  sleep 2

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # If NFS Server then skip CONTAINERD, RUNC AND CNI NETWORK PLUGINS INSTALLATION


clear


if [ $REPLY != 3 ]; then     # If NFS Server then skip KUBELET, KUBEADM & KUBECTL INSTALLATION
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} KUBELET, KUBEADM & KUBECTL INSTALLATION                                                  # START # ${reset}\n"

# There's a dedicated package repository for each Kubernetes minor version on the new package repositories hosted at pkgs.k8s.io - https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction/
VER_K8S_REPO=$(echo $VER_K8S | grep -Eo '[0-9]\.[0-9]+')

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$VER_K8S_REPO/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$VER_K8S_REPO/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

  if [ $([ -s /etc/yum.repos.d/kubernetes.repo ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully created kubernetes repository config file /etc/yum.repos.d/kubernetes.repo" QUIET_NL_PRE
  else
    my_logger ERROR "Failed creating kubernetes repository config file /etc/yum.repos.d/kubernetes.repo" QUIET
  fi

  my_logger INFO "Installing packages:" NL_PRE
  my_logger INFO "   kubelet $VER_K8S: the node agent of Kubernetes, the container cluster manager." NONE
  my_logger INFO "   kubeadm $VER_K8S: command-line utility for administering a Kubernetes cluster." NONE
  my_logger INFO "   kubectl $VER_K8S: Command-line utility for interacting with a Kubernetes cluster." NL_POST
  tdnf -y --disableexcludes install kubelet-${VER_K8S} kubeadm-${VER_K8S} kubectl-${VER_K8S} | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Enabling the kubelet service." QUIET
  systemctl enable --now kubelet
  systemctl status kubelet --no-pager >> $LOG_FILE_NAME
  echo -e "" >> $LOG_FILE_NAME

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  if [ $([ -s /etc/modules-load.d/k8s.conf ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully created kubernetes modules config file /etc/modules-load.d/k8s.conf" QUIET
  else
    my_logger ERROR "Failed creating kubernetes modules config file /etc/modules-load.d/k8s.conf" QUIET
  fi

  modprobe overlay
  modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

  if [ $([ -s /etc/sysctl.d/k8s.conf ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully created kubernetes boot config file /etc/sysctl.d/k8s.conf" QUIET
  else
    my_logger ERROR "Failed creating kubernetes boot config file /etc/sysctl.d/k8s.conf" QUIET
  fi

  my_logger INFO "Reloading from all files referenced at boot time, this includes /etc/sysctl.conf and /etc/sysctl.d/*.conf" QUIET
  sysctl --system | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # If NFS Server then skip KUBELET, KUBEADM & KUBECTL INSTALLATION


clear


if [ $REPLY != 3 ]; then     # If NFS Server then skip OPENVSWITCH INSTALLATION
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} OPENVSWITCH INSTALLATION                                                                 # START # ${reset}\n"

  my_logger INFO "Installing package openvswitch: a production quality, multilayer virtual switch. - Ref. https://www.openvswitch.org" NONE
  tdnf -y install openvswitch | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi      # If NFS Server then skip OPENVSWITCH INSTALLATION


clear


if [ $REPLY != 3 ]; then     # If NFS Server then skip KUBERNETES CLUSTER CONFIGURATION
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} KUBERNETES CLUSTER CONFIGURATION                                                         # START # ${reset}\n"

  if [ $REPLY = 1 ]; then     # Control Plane node
    my_logger INFO "Invoking kubeadm init to initialize the Kubernetes Control Plane Node." NL_POST
    kubeadm init --kubernetes-version=$VER_K8S  --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/16 --v=1 | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

    mkdir -p $HOME/.kube > /dev/null
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config > /dev/null
    chown $(id -u):$(id -g) $HOME/.kube/config > /dev/null
    if [ $([ -s $HOME/.kube/config ]; echo $?) == 0 ]; then
      my_logger INFO "Successfully saved kubeconfig file to $HOME/.kube/config" QUIET
    else
      my_logger ERROR "Failed saving kubeconfig file to $HOME/.kube/config" QUIET
    fi

    kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
    if [ $([ -s /etc/bash_completion.d/kubectl ]; echo $?) == 0 ]; then
      my_logger INFO "Successfully saved kubectl auto-complete configuration file to /etc/bash_completion.d/kubectl" QUIET
    else
      my_logger ERROR "Failed saving kubectl auto-complete configuration file to /etc/bash_completion.d/kubectl" QUIET
    fi
    
  elif [ $REPLY = 2 ]; then     # Worker nodes
    while ! ncat -vz $CP_NODE_IP 6443 > /dev/null 2>&1; do
      my_logger INFO "Waiting for the Kubernetes API Server to start listening on $CP_NODE_IP:6443..." NONE
      sleep 10
    done
    my_logger INFO "Control Plane Node K8S API Server successfully started!" NL_PRE

    TOKEN=$(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'kubeadm token create')
    if [[ ! -z $TOKEN ]]; then
      my_logger INFO "Successfully created the token [$TOKEN] to use for establishing bidirectional trust between nodes and control-plane nodes." QUIET_NL_PRE
    else
      my_logger ERROR "Failed creating the token [$TOKEN] to use for establishing bidirectional trust between nodes and control-plane nodes." QUIET_NL_PRE
    fi
    DISCOVERY=$(sshpass -f .params ssh -o StrictHostKeyChecking=no root@$CP_NODE_IP 'openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed "'"s/^.* //"'"')
    if [[ ! -z $DISCOVERY ]]; then
      my_logger INFO "Successfully created the discovery token [$DISCOVERY] used to validate cluster information fetched from the API server." QUIET
    else
      my_logger ERROR "failed creating the discovery token [$DISCOVERY] used to validate cluster information fetched from the API server." QUIET
    fi

    echo -e "kubeadm join --token ${TOKEN} ${CP_NODE_IP}:6443 --discovery-token-ca-cert-hash sha256:${DISCOVERY}" >> ./join.sh
    chmod 700 ./join.sh > /dev/null

    if [ $([ -s ./join.sh ]; echo $?) == 0 ]; then
      my_logger INFO "Successfully created the kubeadm join script file ./join.sh as: kubeadm join --token ${TOKEN} ${CP_NODE_IP}:6443 --discovery-token-ca-cert-hash sha256:${DISCOVERY}" QUIET
    else
      my_logger ERROR "Failed creating the kubeadm join script file ./join.sh as: kubeadm join --token ${TOKEN} ${CP_NODE_IP}:6443 --discovery-token-ca-cert-hash sha256:${DISCOVERY}" QUIET
    fi

    my_logger INFO "Initializing the Kubernetes Worker Node and joining the Cluster." NL_BOTH
    ./join.sh | tee -a $LOG_FILE_NAME
  fi

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # If NFS Server then skip KUBERNETES CLUSTER CONFIGURATION


clear


if [ $REPLY = 1 ]; then     # Control Plane node
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} ANTREA INSTALLATION                                                                      # START # ${reset}\n"

  while ! ncat -vz localhost 6443 > /dev/null 2>&1; do
    my_logger INFO "Waiting for the local Kubernetes API Server to start listening on port tcp/6443..." NONE
    sleep 10
  done
  my_logger INFO "Local Kubernetes API Server successfully started!" NL_PRE

  my_logger INFO "Deploying Antrea: a Kubernetes-native project that implements the Container Network Interface (CNI) and Kubernetes NetworkPolicy thereby providing network connectivity and security for pod workloads. - Ref. https://github.com/antrea-io/antrea" NL_PRE
  kubectl apply -f https://github.com/antrea-io/antrea/releases/download/v${VER_ANTREA}/antrea.yml | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # If NFS Server then skip ANTREA INSTALLATION


clear


if [ $REPLY = 1 ]; then     # Control Plane node
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} HELM INSTALLATION                                                                        # START # ${reset}\n"

    while [[ ! -z $(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints[*].key}{"\n"}{end}' | grep node.kubernetes.io/not-ready) ]]; do
      my_logger INFO "Waiting for all Kubernetes Cluster Nodes to become Ready..." NONE
      sleep 10
    done
    my_logger INFO "Current Kubernetes Cluster Status:" QUIET
    kubectl get nodes -o wide >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

    my_logger INFO "Installing package Helm: the package manager for Kubernetes. - Ref. https://helm.sh" NL_PRE
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
    
    helm completion bash > /etc/bash_completion.d/helm
    if [ $([ -s /etc/bash_completion.d/helm ]; echo $?) == 0 ]; then
      my_logger INFO "Successfully saved helm auto-complete configuration file to /etc/bash_completion.d/helm" QUIET
    else
      my_logger ERROR "Failed saving helm auto-complete configuration file to /etc/bash_completion.d/helm" QUIET
    fi

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # If NFS Server then skip HELM INSTALLATION


clear


echo -e "${green}################################################################################################### ${reset}"
echo -e "${white} K8S NFS EXTERNAL PROVISIONER INSTALLATION: SUBDIR                                        # START # ${reset}\n"

my_logger INFO "Installing package nfs-utils: contains simple nfs server and client services." NONE
tdnf -y install nfs-utils | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

if [ $REPLY = 1 ]; then     # Control Plane node
  my_logger INFO "Beginning deployment of NFS Subdirectory External Provisioner $VER_SUBDIR: an automatic provisioner for Kubernetes that uses your already configured NFS server, automatically creating Persistent Volumes. - Ref. https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner" NL_PRE
  my_logger INFO "Adding NFS Subdirectory External Provisioner Helm Chart Repository." QUIET
  helm repo add nfs-subdir https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ > /dev/null
  if [[ ! -z $(helm repo list | grep https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner) ]]; then
    my_logger INFO "Successfully added NFS Subdirectory External Provisioner Helm Chart Repository." QUIET
  else
    my_logger ERROR "Failed adding NFS Subdirectory External Provisioner Helm Chart Repository." QUIET
  fi
  NFS_SUBDIR_REPLICAS=$(kubectl get nodes --selector '!node-role.kubernetes.io/control-plane' --output jsonpath="{range .items[?(@)]}{.metadata.name} {.status.conditions[-1].type}{'\n'}{end}" | wc -l)
  my_logger INFO "The desired NFS Subdirectory External Provisioner Pod ReplicaSet size is equal to the number of the current Worker Nodes [$NFS_SUBDIR_REPLICAS]." NL_PRE
  my_logger INFO "Deploying NFS Subdirectory External Provisioner $VER_SUBDIR Helm Chart - NOTE: all Chart configurable parameters can be found at https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/tree/master/charts/nfs-subdir-external-provisioner#configuration" NL_BOTH
  helm install nfs-subdir nfs-subdir/nfs-subdir-external-provisioner --version $VER_SUBDIR --namespace $NFS_NAMESPACE --create-namespace --wait --timeout $HELM_TIMEOUT \
    --set replicaCount=$NFS_SUBDIR_REPLICAS \
    --set storageClass.name=$NFS_SC_NAME \
    --set storageClass.defaultClass=$NFS_SC_DEFAULT \
    --set storageClass.reclaimPolicy=$NFS_SC_RP \
    --set storageClass.archiveOnDelete=$NFS_SC_ARCONDEL \
    --set nfs.server=$NFS_IP \
    --set nfs.path=$NFS_BASEPATH \
    | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
elif [ $REPLY = 3 ]; then     # NFS Server
  my_logger INFO "Creating the basepath of the mount point as ${NFS_BASEPATH}." QUIET
  mkdir $NFS_BASEPATH
  if [ $([ -s $NFS_BASEPATH ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully created the basepath of the mount point as ${NFS_BASEPATH}." QUIET
  else
    my_logger ERROR "Failed creating the basepath of the mount point as ${NFS_BASEPATH}." QUIET
  fi
  echo "${NFS_BASEPATH} *(rw,async,no_root_squash,insecure_locks,sec=sys,no_subtree_check)" >> /etc/exports
  if [ $([ -s /etc/exports ]; echo $?) == 0 ]; then 
    my_logger INFO "Successfully added NFS export configuration to /etc/exports" QUIET
  else 
    my_logger ERROR "Failed adding NFS export configuration to /etc/exports" QUIET
  fi;
  cat /etc/exports >> $LOG_FILE_NAME ; echo "" >> $LOG_FILE_NAME
  my_logger INFO "Enabling the NFS Server service." QUIET
  systemctl enable --now nfs-server.service
  systemctl status nfs-server.service --no-pager >> $LOG_FILE_NAME
fi

echo -e "\n${white}                                                                                            # END # "
echo -e "${green}################################################################################################### ${reset}"


clear


if [ $REPLY = 1 ]; then     # Control Plane node - this 'if..then..else' encapsulates the whole "METALLB AND KUBEAPPS DEPLOYMENT" section
  echo -e "${green}################################################################################################### ${reset}"
  echo -e "${white} METALLB AND KUBEAPPS DEPLOYMENT                                                          # START # ${reset}\n"

  my_logger INFO "Beginning deployment of MetalLB $VER_METALLB: a network load-balancer implementation for Kubernetes using standard routing protocols - Ref. https://metallb.universe.tf" NL_POST
  my_logger INFO "Creating namespace $METALLB_NAMESPACE and configuring pre-requisites. The speaker pod requires elevated permission in order to perform its network functionalities. Hence, the namespace MetalLB is deployed to must be labelled with the following 3 labels: pod-security.kubernetes.io/enforce=privileged - pod-security.kubernetes.io/audit=privileged - pod-security.kubernetes.io/warn=privileged" QUIET
  kubectl create namespace $METALLB_NAMESPACE > /dev/null
  kubectl label namespace $METALLB_NAMESPACE pod-security.kubernetes.io/enforce=privileged > /dev/null
  kubectl label namespace $METALLB_NAMESPACE pod-security.kubernetes.io/audit=privileged > /dev/null
  kubectl label namespace $METALLB_NAMESPACE pod-security.kubernetes.io/warn=privileged > /dev/null
  kubectl describe namespaces $METALLB_NAMESPACE >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Adding MetalLB Helm Chart Repository." QUIET
  helm repo add metallb https://metallb.github.io/metallb > /dev/null
  if [[ ! -z $(helm repo list | grep https://metallb.github.io/metallb) ]]; then
    my_logger INFO "Successfully added MetalLB Helm Chart Repository." QUIET
  else
    my_logger ERROR "Failed adding MetalLB Helm Chart Repository." QUIET
  fi

  my_logger INFO "Deploying MetalLB $VER_METALLB Helm Chart" QUIET
  helm install $METALLB_REL_NAME metallb/metallb --version $VER_METALLB --namespace $METALLB_NAMESPACE --wait --timeout $HELM_TIMEOUT | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
  if [[ ! -z $(helm status $METALLB_REL_NAME -n $METALLB_NAMESPACE | grep "STATUS: deployed") ]]; then
    my_logger INFO "Successfully deployed MetalLB $VER_METALLB Helm Chart." QUIET
  else
    my_logger ERROR "Failed deploying MetalLB $VER_METALLB Helm Chart." QUIET
  fi

  my_logger INFO "Configuring MetalLB IPAddressPool and L2Advertisement." QUIET

cat <<EOF | kubectl apply -f - 
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: $METALLB_IP_POOL
  namespace: $METALLB_NAMESPACE
spec:
  addresses:
  - $METALLB_RANGE_FIRST_IP-$METALLB_RANGE_LAST_IP
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: $METALLB_L2_ADVERT
  namespace: $METALLB_NAMESPACE
EOF

  if [[ ! -z $(kubectl describe ipaddresspools.metallb.io -n $METALLB_NAMESPACE | grep $METALLB_IP_POOL) ]]; then
    my_logger INFO "Successfully created MetalLB IPAddressPool [$METALLB_IP_POOL]." QUIET
  else
    my_logger ERROR "Failed creating MetalLB IPAddressPool [$METALLB_IP_POOL]." QUIET
  fi
  if [[ ! -z $(kubectl describe l2advertisements.metallb.io -n $METALLB_NAMESPACE | grep $METALLB_L2_ADVERT) ]]; then
    my_logger INFO "Successfully created MetalLB IPAddressPool [$METALLB_L2_ADVERT]." QUIET
  else
    my_logger ERROR "Failed creating MetalLB IPAddressPool [$METALLB_L2_ADVERT]." QUIET
  fi

  echo -e "\n"

  my_logger INFO "Beginning deployment of Kubeapps: an in-cluster web-based application that enables users with a one-time installation to deploy, manage, and upgrade applications on a Kubernetes cluster - Ref. https://kubeapps.dev" NL_PRE
  my_logger INFO "Creating namespace [$KUBEAPPS_NAMESPACE]." QUIET
  kubectl create namespace $KUBEAPPS_NAMESPACE > /dev/null
  kubectl describe namespaces $KUBEAPPS_NAMESPACE >> $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME

  my_logger INFO "Deploying Kubeapps Helm Chart" QUIET
  helm install $KUBEAPPS_REL_NAME oci://registry-1.docker.io/bitnamicharts/kubeapps --namespace $KUBEAPPS_NAMESPACE --set frontend.service.type=LoadBalancer --wait --timeout $HELM_TIMEOUT | tee -a $LOG_FILE_NAME; echo "" >> $LOG_FILE_NAME
  if [[ ! -z $(helm status $KUBEAPPS_REL_NAME -n $KUBEAPPS_NAMESPACE | grep "STATUS: deployed") ]]; then
    my_logger INFO "Successfully deployed Kubeapps Helm Chart." QUIET
  else
    my_logger ERROR "Failed deploying Kubeapps Helm Chart." QUIET
  fi

  export METALLB_SERVICE_IP=$(kubectl get svc --namespace $KUBEAPPS_NAMESPACE kubeapps --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
  my_logger INFO "Fetched the Kubeapps Service IP Address (type LoadBalancer) as $METALLB_SERVICE_IP" QUIET

  my_logger INFO "Creating demo Service Account $KUBEAPPS_SERV_ACC with which to access Kubeapps and Kubernetes." QUIET
  kubectl create --namespace default serviceaccount $KUBEAPPS_SERV_ACC > /dev/null
  kubectl create clusterrolebinding $KUBEAPPS_SERV_ACC --clusterrole=cluster-admin --serviceaccount=default:$KUBEAPPS_SERV_ACC > /dev/null

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $KUBEAPPS_SERV_ACC_SECRET
  namespace: default
  annotations:
    kubernetes.io/service-account.name: $KUBEAPPS_SERV_ACC
type: kubernetes.io/service-account-token
EOF

  kubectl get --namespace default secret $KUBEAPPS_SERV_ACC_SECRET -o go-template='{{.data.token | base64decode}}' >> /root/kubeapp-token.txt
  if [ $([ -s /root/kubeapp-token.txt ]; echo $?) == 0 ]; then
    my_logger INFO "Successfully saved demo Service Account $KUBEAPPS_SERV_ACC token to /root/kubeapp-token.txt" QUIET
  else
    my_logger ERROR "Failed saving demo Service Account $KUBEAPPS_SERV_ACC token to /root/kubeapp-token.txt" QUIET
  fi

  echo -e "\n${white}                                                                                            # END # "
  echo -e "${green}################################################################################################### ${reset}"
fi     # this 'if..then..else' encapsulates the whole "METALLB AND KUBEAPPS DEPLOYMENT" section


clear


echo -e "${green}################################################################################################### ${reset}"
echo -e "${green}#                                                                                                 # ${reset}\n"

echo -e "\n${green}                                        SETUP COMPLETE !"
echo -e "\n"

if [ $REPLY = 1 ]; then     # Control Plane node
echo -e "${white}                              Kubeapps URL: https://$METALLB_SERVICE_IP:80"
echo -e "\n"
echo -e "            Kubeapps login token stored on Control Plane node in /root/kubeapp-token.txt"
echo -e "\n"
fi

if [[ ! -z $(cat $LOG_FILE_NAME | grep ERROR) ]]; then
  echo -e "${lired} --> FOUND $(cat $LOG_FILE_NAME | grep ERROR | wc -l) ERROR(S), check log file $LOG_FILE_NAME${reset}"
fi
if [[ ! -z $(cat $LOG_FILE_NAME | grep WARNING) ]]; then
  echo -e "${yellw} --> FOUND $(cat $LOG_FILE_NAME | grep WARNING | wc -l) WARNING(S), check log file $LOG_FILE_NAME${reset}"
fi

echo -e "\n${green}#                                                                                                 # "
echo -e "${green}################################################################################################### ${reset}"

test -f ~/.params && rm ~/.params > /dev/null 2>&1     # not needed anymore, hence it can be deleted (it was storing the Control Plain Node password)
my_logger INFO "Kubernetes Cluster deployment script complete." QUIET
