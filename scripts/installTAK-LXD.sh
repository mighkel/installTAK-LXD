#!/bin/bash
#Version 2.5-LXD
#JR@myTeckNet + LXD Container Enhancements
#
# Usage: 
#   Normal install: ./installTAK <takserver.deb>
#   LXD container:  ./installTAK <takserver.deb> false true
#
# Arguments:
#   $1: Path to TAK Server .deb file (required)
#   $2: FIPS mode (true/false) - default: false  
#   $3: LXD mode (true/false) - default: false
#
#globalVariables
fips=${2:-false}
lxdMode=${3:-false}
sVER="2.5.0"
logfile="/tmp/.takinstall.log"
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
BASEDIR=$(dirname "$(readlink -f "$0")")
curuser=$(printenv SUDO_USER)
homeDir=$(getent passwd "$curuser" | cut -d: -f6)
distro=$(awk -F'=' '/^ID=/ { print tolower($2) }' /etc/*-release | tr -d '"')
distro_ver=$(awk -F'=' '/^VERSION_ID=/ { print tolower($2) }' /etc/*-release | tr -d '"')
model=$(awk -F': ' '/^Model/ {print $2}' /proc/cpuinfo)
memTotal=$(awk -F': ' '/^MemTotal/ {print $2}' /proc/meminfo | tr -d ' kB')

# Script Abort
abort() {
    if [[ -z $ERRoR ]]; then
        echo -e "${RED}ERR: An error has occurred, please check the log file at $logfile.${NC}"
    else
        echo -e "${RED}[$(date +%F-%T) ERR]: $ERRoR${NC}" 2>&1 | tee -a $logfile
    fi
    echo -e "${RED}Task aborted.${NC}"
    exit 1
}

#::::::::::
# LXD Container Networking Verification
#::::::::::
verifyContainerNetworking(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying container networking...${NC}" 2>&1 | tee -a $logfile
        
        # Check internet connectivity
        if ! ping -c 2 8.8.8.8 > /dev/null 2>&1; then
            ERRoR="No internet connectivity detected. Container networking may not be configured.\nSee deployment guide section 5.3b for troubleshooting."
            abort
        fi
        
        # Check DNS resolution
        if ! nslookup archive.ubuntu.com > /dev/null 2>&1; then
            ERRoR="DNS resolution failing. Check /etc/resolv.conf in container."
            abort
        fi
        
        echo -e "${GREEN}✓ Container networking verified${NC}" 2>&1 | tee -a $logfile
    fi
}

#::::::::::
# Prerequisite Checks
#::::::::::
prerequisite(){
    echo -e "${YELLOW}Conducting Prerequisite Checks...${NC}" 2>&1 | tee -a $logfile
    
    # Determine Linux distribution
    if [[ -z $distro ]]; then
        ERRoR="Unable to determine Linux distribution."
        abort
    fi
    
    # Determine Total Memory // RAM
    if [[ $memTotal -lt 7800000 ]]; then
        ERRoR="Minimum 8GB of RAM required."
        abort
    fi
    
    # Determine Linux Version
    case $distro in
        rocky|rhel)
            if ! [[ $distro_ver =~ [8-9] ]]; then
                ERRoR="Platform Version Unsupported."
                abort
            else
                gpgKEY=$(find ${PWD} -name 'takserver-public-gpg.key' -type f -exec ls -t1 {} + | head -1)
                if [[ ! -f $gpgKEY ]]; then
                    ERRoR="takserver-public-gpg.key not found within the directory."
                    abort
                else
                    rpm --import "$gpgKEY"
                fi
            fi
        ;;
        ubuntu)
            # Determine if Ubuntu Version is LTS
            distro_ver=$(awk -F'=' '/^VERSION=/ { print tolower($2) }' /etc/*-release | tr -d '"')
            if ! [[ $distro_ver =~ lts ]]; then
                ERRoR="Platform Version Unsupported."
                abort
            else
                # Determine if deb_policy.pol and takserver-public-gpg.key exists
                debPol=$(find ${PWD} -name 'deb_policy.pol' -type f -exec ls -t1 {} + | head -1)
                gpgKEY=$(find ${PWD} -name 'takserver-public-gpg.key' -type f -exec ls -t1 {} + | head -1)
                if [[ ! -f $gpgKEY ]]; then
                    ERRoR="takserver-public-gpg.key not found within the directory."
                    abort
                else
                    if [[ ! -f $debPol ]]; then
                        ERRoR="deb_policy.pol not found within the directory."
                        abort
                    else
                        # Execute the Ubuntu/Debian Tasks
                        if ! [[ $(apt list --installed | grep -wi 'debsig-verify') ]]; then
                            apt-get install debsig-verify -y 2>&1 | tee -a $logfile
                        fi
                        debPolicyID=$(grep -o 'id="[^"]\+"' "${debPol}" | head -1 | tr -d 'id="')
                        rm -Rf "/usr/share/debsig/keyrings/${debPolicyID}" && mkdir -p "/usr/share/debsig/keyrings/${debPolicyID}"
                        rm -Rf "/etc/debsig/policies/${debPolicyID}" && mkdir -p "/etc/debsig/policies/${debPolicyID}"
                        touch /usr/share/debsig/keyrings/${debPolicyID}/debsig.gpg
                        if ! [[ $(apt list --installed | grep -wi 'gnupg2') ]]; then
                            apt-get install -y gnupg2 2>&1 | tee -a $logfile
                        fi
                        gpg2 --no-default-keyring --keyring /usr/share/debsig/keyrings/${debPolicyID}/debsig.gpg --import ${gpgKEY}
                        cp ${debPol} /etc/debsig/policies/${debPolicyID}/debsig.pol
                        verify_deb=$(debsig-verify $1 | grep -Eo 'Verified')
                        if [[ $verify_deb == "Verified" ]]; then
                            echo -e "${GREEN}Signature Verified.${NC}" 2>&1 | tee -a $logfile
                        else
                            ERRoR="Unable to verify signature."
                            abort
                        fi
                    fi
                fi
            fi
        ;;    
    esac
    echo -e "${GREEN}[1/8]Prerequisite Checks Completed.${NC}" 2>&1 | tee -a $logfile
}

#::::::::::
# PostgreSQL Verification for LXD Containers
#::::::::::
verifyPostgreSQL(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying PostgreSQL initialization...${NC}" 2>&1 | tee -a $logfile
        
        # Wait for PostgreSQL to start
        sleep 5
        
        # Check if PostgreSQL is listening
        if ! ss -tulpn | grep -q ":5432"; then
            echo -e "${YELLOW}PostgreSQL not listening on port 5432, attempting initialization...${NC}" 2>&1 | tee -a $logfile
            
            # Check if data directory exists
            if [ ! -d "/var/lib/postgresql/15/main" ]; then
                echo -e "${YELLOW}Creating PostgreSQL data directory...${NC}" 2>&1 | tee -a $logfile
                mkdir -p /var/lib/postgresql/15/main
                chown -R postgres:postgres /var/lib/postgresql
                sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main 2>&1 | tee -a $logfile
            fi
            
            # Start PostgreSQL cluster
            pg_ctlcluster 15 main start 2>&1 | tee -a $logfile
            sleep 3
            
            # Verify it's now running
            if ! ss -tulpn | grep -q ":5432"; then
                ERRoR="PostgreSQL failed to start. Check logs at /var/log/postgresql/"
                abort
            fi
        fi
        
        echo -e "${GREEN}✓ PostgreSQL verified and running${NC}" 2>&1 | tee -a $logfile
    fi
}

#::::::::::
# Begin RPM/DEB Installation
#::::::::::
Install(){
    takBinary=$1
    dir=/opt/tak
    
    # Gather System Information for logging
    cat /etc/*-release &> $logfile
    echo $model &>> $logfile
    
    # Update JVM limits
    echo -e "${YELLOW}Increasing JVM threads...${NC}"
    echo -e "\n# Applying JVM Limits.\n" &>> $logfile
    echo -e "*      soft      nofile      32768\n*      hard      nofile      32768" | tee --append /etc/security/limits.conf > /dev/null
    echo -e "${GREEN}[2/8] JVM Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    # Install Extra Packages for Linux
    echo -e "${YELLOW}Installing Extra Packages for Linux...${NC}"
    echo -e "\n# Installing Extra Packages for Linux.\n" &>> $logfile
    
    case $distro in
        rocky)
            case $distro_ver in
                8.*) dnf config-manager --set-enabled powertools 2>&1 | tee -a $logfile && dnf install epel-release -y 2>&1 | tee -a $logfile
                ;;
                9.*) dnf config-manager --set-enabled crb 2>&1 | tee -a $logfile && dnf install epel-release -y 2>&1 | tee -a $logfile
                ;;
            esac
            echo -e "${GREEN}[3/8] EPEL Task Complete.${NC}" 2>&1 | tee -a $logfile
        ;;
        rhel)
            echo -e "${YELLOW}Checking RHEL Subscription Status...${NC}"
            sStatus=$(subscription-manager status | grep -Eo "Overall Status: .+" | sed 's/^.\{16\}//') && echo -e "$sStatus" &>> $logfile
            if [[ "$sStatus" == "Unknown" ]]; then
                ERRoR="System not registered with an entitlement server. You can use subscription-manager to register."
                abort
            fi
            case $distro_ver in
                8.*)
                    subscription-manager repos --enable codeready-builder-for-rhel-8-$(arch)-rpms 2>&1 | tee -a $logfile
                    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8 
                    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y 2>&1 | tee -a $logfile
                ;;
                9.*)
                    subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms 2>&1 | tee -a $logfile
                    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9
                    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y 2>&1 | tee -a $logfile
                ;;
            esac
            echo -e "${GREEN}[3/8] EPEL Task Complete.${NC}" 2>&1 | tee -a $logfile
        ;;
        ubuntu|debian)
            echo -e "${GREEN}[3/8] Debian System detected, EPEL Skipped.${NC}" 2>&1 | tee -a $logfile
        ;;
    esac
    
    # Install PostgreSQL and PostGIS
    echo -e "${YELLOW}Installing PostgreSQL and PostGIS...${NC}"
    echo -e "\n# Installing PostgreSQL and PostGIS.\n" &>> $logfile
    
    case $distro in
        rocky|rhel)
            rpm --import https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL
            case $distro_ver in
                8.*) dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-$(arch)/pgdg-redhat-repo-latest.noarch.rpm -y 2>&1 | tee -a $logfile
                ;;
                9.*) dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(arch)/pgdg-redhat-repo-latest.noarch.rpm -y 2>&1 | tee -a $logfile
                ;;
            esac
            dnf -qy module disable postgresql &>> $logfile
            echo -e "${GREEN}[4/8] PostgreSQL and PostGIS Task Complete.${NC}" 2>&1 | tee -a $logfile
        ;;
        ubuntu|debian)
            apt-get install curl ca-certificates -y 2>&1 | tee -a $logfile
            install -d /usr/share/postgresql-common/pgdg
            curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
            sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
            echo -e "${GREEN}[4/8] PostgreSQL and PostGIS Task Complete.${NC}" 2>&1 | tee -a $logfile
            apt update -y 2>&1 | tee -a $logfile
        ;;
    esac
    
    # Install Java-OpenJDK
    echo -e "${YELLOW}Installing Java-OpenJDK...${NC}"
    echo -e "\n# Installing Java-OpenJDK.\n" &>> $logfile
    
    case $distro in
        rocky|rhel)
            dnf install java-17-openjdk-devel -y 2>&1 | tee -a $logfile
        ;;
        ubuntu|debian)
            apt-get install openjdk-17-jre -y 2>&1 | tee -a $logfile
        ;;
    esac
    echo -e "${GREEN}[5/8] Java-OpenJDK Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    # Perform TAK Server Installation
    echo -e "${YELLOW}Installing $takBinary...${NC}"
    echo -e "\n# Installing $takBinary.\n" &>> $logfile
    
    case $distro in
        rocky|rhel)
            if [[ $(dnf list installed | grep -wi 'takserver.noarch') ]]; then
                dnf reinstall $takBinary -y 2>&1 | tee -a $logfile
            else
                dnf install $takBinary -y 2>&1 | tee -a $logfile
            fi
            servicePostgreSQL="postgresql-15"
        ;;
        ubuntu|debian)
            apt-get install ./$takBinary -y --reinstall 2>&1 | tee -a $logfile
            servicePostgreSQL="postgresql"
        ;;
    esac
    
    # Check TAK Server installation
    if [ $(systemctl is-active $servicePostgreSQL) == active ]; then
        echo -e "${GREEN}[6/8] Installation of $takBinary Task Complete.${NC}" 2>&1 | tee -a $logfile
    else
        echo -e "${RED}[6/8] Installation of $takBinary Task, PostgreSQL/PostGIS Service not found.${NC}" 2>&1 | tee -a $logfile
        ERRoR="Installation of $takBinary Task, PostgreSQL/PostGIS Service not found."
        abort
    fi
    
    # Configure SELinux
    echo -e "${YELLOW}Configuring SELinux...${NC}"
    echo -e "\n# Configuring SELinux.\n" &>> $logfile
    
    if [ $distro == "rocky" ]; then 
        echo -e "\n# [Rocky Linux] Installing checkpolicy.\n" &>> $logfile
        dnf install checkpolicy -y 2>&1 | tee -a $logfile
        echo -e "${GREEN}[Rocky Linux] Installation of checkpolicy Task Complete.${NC}" 2>&1 | tee -a $logfile
    fi
    
    if [ $distro == "rocky" ] || [ $distro == "rhel" ]; then
        cd $dir && ./apply-selinux.sh 2>&1 | tee -a $logfile
        cd $homeDir
    fi
    
    echo -e "${GREEN}[7/8] Configuring SELinux Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    # Install additional dependencies
    echo -e "${YELLOW}Install Additional Dependencies...${NC}"
    echo -e "\n# Installing Additional Dependencies.\n" &>> $logfile    
    
    case $distro in
        rocky|rhel)
            dnf install dialog zip unzip -y 2>&1 | tee -a $logfile
        ;;
        ubuntu|debian)
            apt-get install dialog zip unzip uuid-runtime -y 2>&1 | tee -a $logfile
        ;;
    esac
    
    cp $dir/CoreConfig.example.xml $dir/CoreConfig.example.xml.bak
    echo -e "${GREEN}[8/8] Dependency Installation Task Complete.${NC}" 2>&1 | tee -a $logfile
}

#::::::::::
# TAK Wizard Text User Interface
#::::::::::
splash(){
    exec 3>&1
    if [[ $lxdMode == "true" ]]; then
        dialog --backtitle "$backTitle" --title "- TAK Setup Wizard (LXD Mode) -" --ok-label "Continue" --msgbox \
"WELCOME to the TAK initial setup script (LXD Container Mode).

This script will guide you through the initial configuration needed to complete your setup of TAK Server.

IMPORTANT - LXD Mode Notes:
  • Lets Encrypt will be configured LATER in Phase 5 (Networking)
  • Choose 'Local (self-signed)' when prompted for FQDN trust
  • Network port forwarding is configured in Phase 5

Navigation around the menu boxes is done using the <arrow keys> or <tab>.

Selecting options in a checklist is best done using the <spacebar>.

Hit enter to continue." 0 0
    else
        dialog --backtitle "$backTitle" --title "- TAK Setup Wizard-" --ok-label "Continue" --msgbox \
"WELCOME to the TAK initial setup script.

This script will guide you through the initial configuration needed to complete your setup of TAK Server.

Navigation around the menu boxes is done using the <arrow keys> or <tab>.

Selecting options in a checklist is best done using the <spacebar>.

Hit enter to continue." 0 0
    fi
    exec 3>&-
}

# Certificate Properties
set-certproperties(){
    public_IP=$(curl -s https://api.ipify.org)
    public_geoIP=$(curl -s http://ip-api.com/line/$public_IP?fields=8218)
    IFS=$'\n' read -r -d '' -a geoIPInfo < <(echo "$public_geoIP" | sed 's/ \([A-Za-z]*:\) /\n\1 /g')
    
    if ! [[ ${certconfig[0]} ]]; then
        Country=${geoIPInfo[0]}
    else
        Country=${certconfig[0]}
    fi
    
    if ! [[ ${certconfig[1]} ]]; then
        State=${geoIPInfo[1]}
    else
        State=${certconfig[1]}
    fi
    
    if ! [[ ${certconfig[2]} ]]; then
        City=${geoIPInfo[2]}
    else
        City=${certconfig[2]}
    fi
    
    if ! [[ ${certconfig[3]} ]]; then
        Organization="TAK"
    else
        Organization=${certconfig[3]}
    fi
    
    if ! [[ ${certconfig[4]} ]]; then
        Organizational_Unit="TAK"
    else
        Organizational_Unit=${certconfig[4]}
    fi
    
    oldIFS="$IFS"
    IFS=$'\n'
    exec 3>&1
    certconfig=($(dialog --clear --ok-label "Submit" --no-cancel --backtitle "$backTitle" --title "TAK PKI Configuration" \
    --form "The following values are required for the self-signed certificate signing request.  The information will be used to identify the certificate via its Distinguished Name or DN."'
    '"\n\nSet the following options for your certificate request."'
    '"\n\nUse the UP and DOWN Arrow Keys to navigate; TAB to SUBMIT." 0 0 0 \
    "Country:" 1 1 "$Country" 1 20 30 0 \
    "State:" 2 1 "$State" 2 20 30 0 \
    "City:" 3 1 "$City" 3 20 30 0 \
    "Organization:" 4 1 "$Organization" 4 20 30 0 \
    "Organizational Unit:" 5 1 "$Organizational_Unit" 5 20 30 0 \
    2>&1 1>&3))
    exec 3>&-
}

apply-certproperties(){
    echo -e "${YELLOW}Applying Certificate Properties...${NC}"
    echo -e "\n# Applying Certificate Properties.\n" &>> $logfile
    
    certCountry=$(awk -F'=' '/^COUNTRY=/ { print $2 }' $dir/certs/cert-metadata.sh | tr -d '"')
    certState=$(awk -F'=' '/^STATE=/ { print $2 }' $dir/certs/cert-metadata.sh | tr -d '"')
    certCity=$(awk -F'=' '/^CITY=/ { print $2 }' $dir/certs/cert-metadata.sh | tr -d '"')
    certOrg=$(awk -F'=' '/^ORGANIZATION=/ { print $2 }' $dir/certs/cert-metadata.sh | tr -d '"')
    certOrgUnit=$(awk -F'=' '/^ORGANIZATIONAL_UNIT=/ { print $2 }' $dir/certs/cert-metadata.sh | tr -d '"')

    sed -i 8,15s/$certCountry/"'"${certconfig[0]}"'"/g $dir/certs/cert-metadata.sh
    sed -i 8,15s/$certState/"'"${certconfig[1]}"'"/g $dir/certs/cert-metadata.sh
    sed -i 8,15s/$certCity/"'"${certconfig[2]}"'"/g $dir/certs/cert-metadata.sh
    sed -i 8,15s/$certOrg/"'"${certconfig[3]}"'"/g $dir/certs/cert-metadata.sh
    sed -i 8,15s/$certOrgUnit/"'"${certconfig[4]}"'"/g $dir/certs/cert-metadata.sh
    
    echo -e "${GREEN}[1/7] Applying Certificate Properties Task Complete.${NC}" 2>&1 | tee -a $logfile
}

# Certificate Password
set-certauthpass() {
    exec 3>&1
    # Prompt to change the default certificate password
    dialog --backtitle "$backTitle" --title "TAK PKI Configuration" --defaultno \
        --yesno "By default the certificate password is 'atakatak'."' 
'"\n\nwould you like to change it?" 0 0 \
        2>&1 1>&3
    # Exit status
    certpasswd=$?
    
    if [ $certpasswd = 0 ]; then
        CAPASSWD=$CAPASSWD
        CAPASSWD=($(dialog --clear --no-cancel --backtitle "$backTitle" \
            --title "TAK PKI Configuration" \
            --inputbox "Enter new certificate password:" \
            0 0 \
            2>&1 1>&3))
        # Exit status
        caResponse=$?
    else
        CAPASSWD=atakatak
    fi
    exec 3>&-
}

apply-certauthpass() {
    if [[ $caResponse = 0 ]]; then
        echo -e "${YELLOW}Applying Certificate Password...${NC}"
        echo -e "\n# Applying Certificate Password.\n" &>> $logfile
        sed -i s/atakatak/$CAPASSWD/g $dir/certs/cert-metadata.sh
        sed -i "s/atakatak/$CAPASSWD/g" $exampleconfigxml
        echo -e "${GREEN}Applying Certificate Password Task Complete.${NC}" &>> $logfile
    else
        echo -e "${YELLOW}Certificate Password Unchanged...${NC}"
        echo -e "\n# Certificate Password Unchanged.\n" &>> $logfile
        CAPASSWD=atakatak
    fi
}

# Public/Private Key Infrastructure
set-certauthname() {
    rootCA="${rootCA}"
    intCA="${intCA}"
    exec 3>&1
    
    # Prompt for Root Certificate Authority Name
    rootCA="$(dialog --clear --no-cancel --backtitle "$backTitle" \
        --title "TAK PKI Configuration" \
        --inputbox "The Root Certificate Authority is the first certificate in the PKI environment.  It will be used to sign the issuing CA next."'
'"\n\nEnter a name for the Root CA:" 0 0 \
        2>&1 1>&3)"
    
    if [[ $rootCA = "" ]]; then
        rootCA="$(date +%s%N | sha256sum | base64 | head -c 12)-ROOT-CA-01"
    else
        # Convert spaces to dash
        rootCA="${rootCA// /-}"
        # Change case to Upper
        rootCA=$(echo "$rootCA" | tr [a-z] [A-Z])
    fi
    
    # Prompt for Intermediate Certificate Authority Name
    intCA="$(dialog --clear --no-cancel --backtitle "$backTitle" \
        --title "TAK PKI Configuration" \
        --inputbox "The Intermediate CA will act as the Issuing CA for all certificates on the behalf of the Root CA."'
'"\n\nEnter a name for the Intermediate CA:" 0 0 \
        2>&1 1>&3)"
    
    if [[ $intCA = "" ]]; then
        intCA="$(date +%s%N | sha256sum | base64 | head -c 12)-CA-01"
    else
        # Convert spaces to dash
        intCA="${intCA// /-}"
        # Change case to Upper
        intCA=$(echo "$intCA" | tr [a-z] [A-Z])
    fi
    exec 3>&-
}

apply-certauthname() {
    echo -e "${YELLOW}Creating Root Certificate Authority ${rootCA}...${NC}"
    echo -e "\n# Creating Root Certificate Authority ${rootCA}.\n" &>> $logfile
    
    # Create new RootCA
    cd $dir/certs || exit
    if [[ $fips == "true" ]]; then
        $makerootca --ca-name "$rootCA" --fips
    else
        $makerootca --ca-name "$rootCA"
    fi
    echo -e "${GREEN}[2/7]Creating Root Certificate Authority ${rootCA} Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    # Create Intermediate CA
    echo -e "${YELLOW}Creating Intermediate/Issuing Certificate Authority ${intCA}...${NC}"
    echo -e "\n# Creating Intermediate/Issuing Certificate Authority ${intCA}.\n" &>> $logfile
    if [[ $fips == "true" ]]; then
        echo y | $makeCert ca "$intCA" --fips
    else
        echo y | $makeCert ca "$intCA"
    fi
    echo -e "${GREEN}[3/7] Creating Intermediate/Issuing Certificate Authority ${intCA} Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    echo -e "${YELLOW}Updating the CoreConfiguration Files...${NC}"
    echo -e "\n# Updating the CoreConfiguration Files.\n" &>> $logfile
    
    # Update the CoreConfig.example.xml for the truststore
    sed -i "s/truststore-root/truststore-$intCA/g" $exampleconfigxml
    
    # Update the CoreConfig.example.xml for the CRL
    crl=$"\    \n    <crl _name=\"TAKServer CA\" crlFile=\"certs/files/${intCA}.crl\"/>"
    # Append CRL
    sed -i "119i $crl" $exampleconfigxml # 118 // TAK Server 5.3 or Older
    
    echo -e "${GREEN}[4/7] Updating the CoreConfiguration Files Task Complete.${NC}" 2>&1 | tee -a $logfile
    
    # Create new TAK Server Certificate
    echo -e "${YELLOW}Creating the Client Certificate for ${HOSTNAME}...${NC}"
    echo -e "\n# Creating the Client Certificate for ${HOSTNAME}.\n" &>> $logfile
    if [[ $fips == "true" ]]; then
        $makeCert server ${HOSTNAME} --fips
    else
        $makeCert server ${HOSTNAME}
    fi
    
    sed -i "s/takserver.jks/${HOSTNAME}.jks/g" $exampleconfigxml
    
    echo -e "${GREEN}[5/7] Creating the Client Certificate for ${HOSTNAME} Task Complete.${NC}" 2>&1 | tee -a $logfile
}

# Certificate Enrollment Configuration
set-certautoenroll() {
    exec 3>&1
    dialog --backtitle "$backTitle" \
        --title "Certificate Auto-Enrollment Configuration" \
        --yesno "Certificate Auto-Enrollemnt enables the client to request a certificate from the TAK Server without the need to pass soft certificates to the TAK Clients."'
    '"\n\nDo you want to enable Certificate Auto-Enrollement?" 0 0 \
        2>&1 1>&3
    # Exit Status
    certAEnrollment=$?
    exec 3>&-
}

apply-certautoenroll() {
    if [ $certAEnrollment = 0 ]; then
        echo -e "${YELLOW}Applying Certificate Auto Enrollment Configuration...${NC}"
        echo -e "\n# Applying Certificate Auto Enrollment Configuration.\n" &>> $logfile
        
        CertificateAutoEnrollment=$"\    \n<certificateSigning CA=\"TAKServer\">\n	<certificateConfig>\n		<nameEntries>\n			<nameEntry name=\"O\" value=\"${certconfig[3]}\"\/>\n			<nameEntry name=\"OU\" value=\"${certconfig[4]}\"\/>\n		</nameEntries>\n	</certificateConfig>\n	    <TAKServerCAConfig keystore=\"JKS\" keystoreFile=\"certs/files/${intCA}-signing.jks\" keystorePass=\"${CAPASSWD}\" validityDays=\"30\" signatureAlg=\"SHA256WithRSA\" CAkey=\"/opt/tak/certs/files/${intCA}\" CAcertificate=\"/opt/tak/certs/files/${intCA}\" \/>\n    </certificateSigning>"
        sed -i "/<\/buffer>/a $CertificateAutoEnrollment" $exampleconfigxml
        sed -i 's/<auth>/<auth x509groups="true" x509groupsDefaultRDN="true" x509addAnonymous="false" x509useGroupCache="true" x509checkRevocation="true">/g' $exampleconfigxml      
        
        case $distro in
            rocky|rhel)
                firewall-cmd --zone=public --add-port 8446/tcp --permanent >/dev/null
                firewall-cmd --reload >/dev/null
            ;;
            ubuntu|debian)
                apt-get install ufw -y 2>&1 | tee -a $logfile
                # Initial Firewall Rules
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow ssh
                ufw allow 8446 >/dev/null
            ;;
        esac
        
        echo -e "${GREEN}[6/7] Applying Certificate Auto Enrollment Configuration Task Complete.${NC}" 2>&1 | tee -a $logfile
    else
        echo -e "${GREEN}[6/7] SKIP Certificate Auto Enrollment Configuration Task.${NC}" 2>&1 | tee -a $logfile
    fi
}

# TAK Federation Configuration
set-takfederation() {
    exec 3>&1
    dialog --backtitle "$backTitle" \
        --title "Federation Configuration" \
        --yesno "Federation allows TAK clients connected to the TAK Server to share data across different connected networks.\n\n"'
'"Federation requires the exchanging of the TAK Server CAs to establish a secure server to server connection for sharing information."'
'"\n\nDo you want to enable TAK Server Federation v2?" 0 0 \
        2>&1 1>&3
    serverFederation=$?
    exec 3>&-
}

apply-takfederation() {
    if [ $serverFederation = 0 ]; then
        echo -e "${YELLOW}Applying TAK Server Federation Configuration...${NC}"
        echo -e "\n# Applying TAK Server Federation Configuration.\n" &>> $logfile
        
        fedEnabled=$"\    \n<federation allowFederatedDelete=\"false\" allowMissionFederation=\"true\" allowDataFeedFederation=\"true\" enableMissionFederationDisruptionTolerance=\"true\" missionFederationDisruptionToleranceRecencySeconds=\"43200\" enableFederation=\"true\" federatedGroupMapping=\"true\" automaticGroupMapping=\"false\" enableDataPackageAndMissionFileFilter=\"false\">\n      <federation-server port=\"9000\" coreVersion=\"2\" v1enabled=\"false\" v2port=\"9001\" v2enabled=\"true\">\n        <tls context=\"TLSv1.2\" keymanager=\"SunX509\" keystore=\"JKS\" keystoreFile=\"certs/files/${HOSTNAME}.jks\" keystorePass=\"${CAPASSWD}\" truststore=\"JKS\" truststoreFile=\"certs/files/fed-truststore.jks\" truststorePass=\"${CAPASSWD}\"/>\n		    <federation-port port=\"9000\" tlsVersion=\"TLSv1.2\"/>\n            <v1Tls tlsVersion=\"TLSv1.2\"/>\n            <v1Tls tlsVersion=\"TLSv1.3\"/>\n      </federation-server>\n	    <fileFilter>\n            <fileExtension>pref</fileExtension>\n        </fileFilter>\n    </federation>\n"
        
        if [ $certAEnrollment = 0 ]; then
            sed -i "/<\/security>/a $fedEnabled" $exampleconfigxml # 144 // TAK Server 5.3 or Older
            sed -i '156,165d' $exampleconfigxml # Remove older federation config
        else
            sed -i "/<\/security>/a $fedEnabled" $exampleconfigxml # 134 No Certificate Auto Enrollment
            sed -i '147,155d' $exampleconfigxml
            sed -i 's/<auth>/<auth x509groups="true" x509groupsDefaultRDN="true" x509addAnonymous="false">/g' $exampleconfigxml
        fi
        
        case $distro in
            rocky|rhel)
                firewall-cmd --zone=public --add-port 9001/tcp --permanent >/dev/null
                firewall-cmd --reload >/dev/null
            ;;
            ubuntu|debian)
                ufw allow 9001 >/dev/null
            ;;
        esac
        
        echo -e "${GREEN}[7/7] Applying TAK Server Federation Configuration Task Complete.${NC}" 2>&1 | tee -a $logfile
    else
        echo -e "${GREEN}[7/7] SKIP TAK Server Federation Configuration Task.${NC}" 2>&1 | tee -a $logfile
    fi
}

#::::::::::
# LXD Mode: Skip Let's Encrypt, Use Local Certs Only
#::::::::::
set-FQDN-lxd(){
    if [[ $lxdMode == "true" ]]; then
        exec 3>&1
        dialog --backtitle "$backTitle" --title "- FQDN Configuration (LXD Mode) -" --ok-label "Continue" --msgbox \
"IMPORTANT: Let's Encrypt Setup Deferred

In LXD container mode, Lets Encrypt SSL certificates will be configured LATER in Phase 5 (Networking) after:

  • Port forwarding is configured (80/tcp, 443/tcp)
  • Reverse proxy is set up
  • DNS is properly configured

For now, we will use LOCAL self-signed certificates.

Press Continue to proceed with local certificates." 0 0
        exec 3>&-
        
        # Get FQDN but don't set up Let's Encrypt
        resolve_dns=$(curl -s https://api.hackertarget.com/reversedns/?q=$public_IP)
        IFS=' ' read -r -a resolveDNS <<< "$resolve_dns"
        if ! [[ ${resolveDNS[1]} ]]; then
            FQDName=${resolveDNS[1]}
        else
            FQDName=$public_IP
        fi
        
        exec 3>&1
        serverEndPoint=($(dialog --clear --no-cancel --backtitle "$backTitle" \
            --title "TAK Server Fully Qualified Domain Name (FQDN)" \
            --ok-label "Continue" \
            --inputbox "Enter the FQDN for this TAK Server (will use local certs for now):

Lets Encrypt will be configured in Phase 5 (Networking)." \
            0 0 "$FQDName" 2>&1 1>&3))
        exec 3>&-
        
        # Save FQDN for later Let's Encrypt setup
        echo "$serverEndPoint" > /opt/tak/fqdn-for-letsencrypt.txt
        
        echo -e "${YELLOW}[LXD Mode] FQDN saved: $serverEndPoint${NC}" 2>&1 | tee -a $logfile
        echo -e "${YELLOW}[LXD Mode] Let's Encrypt will be configured in Phase 5${NC}" 2>&1 | tee -a $logfile
    fi
}

# Client Connection Support
set-takConnector(){
    oldIFS="$IFS"
    IFS=$'\n'
    exec 3>&1
    takConnectorType=($(dialog --clear --ok-label "Continue" --no-cancel --backtitle "$backTitle" --title "TAK Server Connection Type" --checklist "To connect to the TAK Server, clients must connect securely to an open port on both the server and network.\n\n"'
'"The TAK Server supports two types of connections: TCP/SSL and UDP/QUIC.  Select the type of connection to support based on your network requirements.\n\n"'
'"- TCP/SSL is the default and communicates over TCP/8089, selecting this option will allow TCP inbound connections to this server.\n\n"'
'"- UDP/QUIC is an alternate communications port over UDP/8090, selecting this option will allow UDP inbound connections to this server.\n\n"'
'"Select SSL, QUIC or both to support this type of connection." 19 85 0 \
        SSL "Enable TCP/SSL/TLS Connections" on \
        QUIC "Enable UDP/QUIC Connections" off \
        2>&1 1>&3))
    exec 3>&-
    IFS="$oldIFS"
}

apply-takConnector(){
    if ! [[ $takConnectorType ]]; then
        exec 3>&1
        dialog --clear --infobox "Try Again" 10 30
        exec 3>&-
        set-takConnector
    else
        case $takConnectorType in
            "SSL")
                case $distro in
                    rocky|rhel)
                        firewall-cmd --zone=public --add-port 8089/tcp --permanent >/dev/null
                        firewall-cmd --reload >/dev/null
                    ;;
                    ubuntu|debian)
                        ufw allow 8089 >/dev/null
                    ;;
                esac
            ;;
            "QUIC") 
                sed -i "7i <input _name=\"quic\" protocol=\"quic\" port=\"8090\" coreVersion=\"2\"/>" $exampleconfigxml
                case $distro in
                    rocky|rhel)
                        firewall-cmd --zone=public --add-port 8090/udp --permanent >/dev/null
                        firewall-cmd --reload >/dev/null
                    ;;
                    ubuntu|debian)
                        ufw allow 8090/udp >/dev/null
                    ;;
                esac            
            ;;
            "SSL QUIC") 
                sed -i "7i <input _name=\"quic\" protocol=\"quic\" port=\"8090\" coreVersion=\"2\"/>" $exampleconfigxml
                case $distro in
                    rocky|rhel)
                        firewall-cmd --zone=public --add-port 8089/tcp --add-port 8090/udp --permanent >/dev/null
                        firewall-cmd --reload >/dev/null
                    ;;
                    ubuntu|debian)
                        ufw allow 8089 >/dev/null
                        ufw allow 8090/udp >/dev/null
                    ;;
                esac
            ;;
        esac
    fi
}

# WebTAK Options
set-webTAKOptions(){
    if [ $certAEnrollment = 0 ]; then
        oldIFS="$IFS"
        IFS=$'\n'
        exec 3>&1
        webTAKOptions=($(dialog --clear --ok-label "Continue" --no-cancel --backtitle "$backTitle" --title "TAK Server WebTAK Options" --checklist "With Certificate Enrollment enabled users can authenitcate using credentials for WebTAK.\n\n"'
'"As the administrator the following options are available to secure access to WebTAK using credentials.  The use of poor password complexity can increase the risk to the TAK Server.\n\n"'
'"- enableAdminUI enables the management console for administrator accounts who successfully authenticate.\n\n"'
'"- enableWebtak enables WebTAK over credentials at https://$serverIP:8446/webtak for example.\n\n"'
'"- enableNonAdminUI enabled the management console for any non-administrator who successfully authenticates.\n\n"'
'"Select the options you wish to enable:" 24 85 0 \
            enableAdminUI "Enable Admin UI" off \
            enableWebtak "Enable WebTAK" off \
            enableNonAdminUI "Enable NonAdminUI" off \
                2>&1 1>&3))
        exec 3>&-
        IFS="$oldIFS"
    fi
}

apply-webTAKOptions(){
    if [ $certAEnrollment = 0 ]; then
        if ! [[ $webTAKOptions ]]; then
            # Turn off all options
            sed -i 's/"cert_https"\//"cert_https" enableAdminUI="false" enableWebtak="false" enableNonAdminUI="false"\//g' $exampleconfigxml
        else
            case $webTAKOptions in
                "enableAdminUI")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="true" enableWebtak="false" enableNonAdminUI="false"\//g' $exampleconfigxml
                ;;
                "enableWebtak")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="false" enableWebtak="true" enableNonAdminUI="false"\//g' $exampleconfigxml
                ;;
                "enableNonAdminUI")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="false" enableWebtak="false" enableNonAdminUI="true"\//g' $exampleconfigxml
                ;;
                "enableAdminUI enableWebtak")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="true" enableWebtak="true" enableNonAdminUI="false"\//g' $exampleconfigxml
                ;;
                "enableAdminUI enableNonAdminUI")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="true" enableWebtak="false" enableNonAdminUI="true"\//g' $exampleconfigxml
                ;;
                "enableWebtak enableNonAdminUI")
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="false" enableWebtak="true" enableNonAdminUI="true"\//g' $exampleconfigxml
                ;;
                "enableAdminUI enableWebtak enableNonAdminUI") 
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="true" enableWebtak="true" enableNonAdminUI="true"\//g' $exampleconfigxml
                ;;
                *) 
                    sed -i 's/"cert_https"\//"cert_https" enableAdminUI="false" enableWebtak="false" enableNonAdminUI="false"\//g' $exampleconfigxml
                ;;
            esac
        fi
    fi
}

# Establish the DataPackage/Enrollment Process
create-datapackage() {
    # Create temp dir
    mkdir /tmp/enrollmentDP
    cd /tmp/enrollmentDP || exit
    UUID=$(uuidgen -r)
    IFS=$'\n'
    serverIP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
    
    exec 3>&1
    serverDesc="${HOSTNAME}"
    serverDesc=($(dialog --clear --no-cancel --backtitle "$backTitle" --title "TAK Server Description" --ok-label "Create DataPackage" \
        --inputbox "Enter a short description of this TAK Server connection to be displayed on the TAK Client." \
        0 0 "TAK Server" 2>&1 1>&3))
    exec 3>&-
    
    # In LXD mode, use saved FQDN or fallback to IP
    if [[ $lxdMode == "true" ]]; then
        if [ -f /opt/tak/fqdn-for-letsencrypt.txt ]; then
            serverEndPoint=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
        else
            serverEndPoint=$serverIP
        fi
    else
        serverEndPoint=$serverIP
    fi
    
    case $takConnectorType in
        "SSL") connectorPort="8089:ssl";;
        "QUIC") connectorPort="8090:quic";;
        "SSL QUIC") connectorPort="8089:ssl"
            connectorPort2="8090:quic";;
    esac
    
    # config.cnf
    tee config.pref >/dev/null <<EOF
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
<preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">$serverDesc</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">$serverEndPoint:$connectorPort</entry>
    <entry key="caLocation0" class="class java.lang.String">cert/caCert.p12</entry>
    <entry key="caPassword0" class="class java.lang.String">$CAPASSWD</entry>
    <entry key="enrollForCertificateWithTrust0" class="class java.lang.Boolean">true</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">true</entry>
    <entry key="cacheCreds0" class="class java.lang.String">Cache credentials</entry>
</preference>
<preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="network_quic_enabled" class="class java.lang.Boolean">true</entry>
    <entry key="apiSecureServerPort" class="class java.lang.String">8443</entry>
    <entry key="apiCertEnrollmentPort" class="class java.lang.String">8446</entry>
    <entry key="locationTeam" class="class java.lang.String">Blue</entry>
    <entry key="atakRoleType" class="class java.lang.String">Team Member</entry>
</preference>
</preferences>
EOF

    # MANIFEST.xml
    tee MANIFEST.xml >/dev/null <<EOF
<MissionPackageManifest version="2">
<Configuration>
    <Parameter name="uid" value="$UUID"/>
    <Parameter name="name" value="enrollmentDP.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
</Configuration>
<Contents>
    <Content ignore="false" zipEntry="config.pref"/>
    <Content ignore="false" zipEntry="caCert.p12"/>
</Contents>
</MissionPackageManifest>
EOF

    echo $serverDesc > $dir/takdatapackagedesc
    echo $serverEndPoint >> $dir/takdatapackagedesc
    
    cp $certs/truststore-$intCA.p12 /tmp/enrollmentDP/caCert.p12
    zip -j $homeDir/enrollmentDP.zip /tmp/enrollmentDP/*
    
    if [ -v connectorPort2 ];then
        sed -i "s/8089:ssl/$connectorPort2/g" /tmp/enrollmentDP/config.pref
        sed -i "s/enrollmentDP/enrollmentDP-QUIC/g" /tmp/enrollmentDP/MANIFEST.xml
        zip -j $homeDir/enrollmentDP-QUIC.zip /tmp/enrollmentDP/*
    fi
    
    chown -R "$curuser":"$curuser" $homeDir
    cd /tmp
    rm -Rf enrollmentDP
    IFS="$oldIFS"
}

create-webadmin(){
    echo -e "${YELLOW}Creating Admin Certificate...${NC}"
    echo -e "\n# Creating Admin Certificate.\n" &>> $logfile
    
    cd $dir/certs || exit
    if [[ $fips == "true" ]]; then
        echo y | $makeCert client webadmin --fips
    else
        echo y | $makeCert client webadmin
    fi
    
    java -jar $dir/utils/UserManager.jar certmod -A $certs/webadmin.pem
    cp $certs/webadmin.p12 $homeDir/
    chown -R "$curuser":"$curuser" $homeDir
    chown -R tak:tak $dir
    
    echo -e "${GREEN}Creating Admin Certificate Task Complete.${NC}" 2>&1 | tee -a $logfile
}

# Display the Review Changes Screen
finalize-install() {
    exec 3>&1
    
    if [[ $certAEnrollment = 0 ]]; then
        enrollmentState="Enabled"
    else
        enrollmentState="Disabled"
    fi
    
    if [[ $serverFederation = 0 ]]; then
        federationState="Enabled"
    else
        federationState="Disabled"
    fi
    
    if ! [[ $webTAKOptions ]]; then
        webTAKOptions="Disabled"
    fi
    
    if [[ $lxdMode == "true" ]]; then
        letsencryptNote="\nLets Encrypt: DEFERRED to Phase 5 (Networking)\n"
    else
        letsencryptNote=""
    fi
    
    dialog --backtitle "$backTitle" --title "Configuration Summary" --scrollbar --defaultno --yes-label "Confirm" --no-label "Reset Wizard" --yesno \
        "The TAK Server will be initialized with the following configuration:\n"'
    '"\nCertificate Information\n"'
    '"Country: ${certconfig[0]}\n"'
    '"State: ${certconfig[1]}\n"'
    '"City: ${certconfig[2]}\n"'
    '"Organization: ${certconfig[3]}\n"'
    '"Organizational_Unit: ${certconfig[4]}\n"'
    '"Certificate Password: $CAPASSWD\n"'
    '"Root CA Name: $rootCA\n"'
    '"Intermediate/Subordinate CA Name: $intCA\n"'
    '"\nOptional Configuration Settings\n"'
    '"Certificate Enrollment: $enrollmentState\n"'
    '"WebTAK Options: $webTAKOptions\n"'
    '"Federation: $federationState\n"'
    '"FIPS: $fips\n"'
    '"TAK Connection Type: $takConnectorType\n"'
    '"$letsencryptNote"'
    '"\nSelect Confirm to continue.  Reset to Restart the Config Wizard." 0 0 2>&1 1>&3
    return=$?
    
    if [ $return = 1 ]; then
        takWizard
    else
        executeConfiguration
    fi
    exec 3>&-
}

# Establish the Wizard Workflow
takWizard(){
    # RPM/DEB Global Variables
    javaconf="/usr/lib/jvm/java-17-openjdk-*"
    javasecurity=$javaconf/conf/security/java.security
    certs=$dir/certs/files
    configxml=$dir/CoreConfig.xml
    exampleconfigxml=$dir/CoreConfig.example.xml
    makerootca=$dir/certs/makeRootCa.sh
    makeCert=$dir/certs/makeCert.sh        
    
    splash
    set-certproperties
    set-certauthpass
    set-certauthname
    set-certautoenroll
    set-takfederation
    
    # LXD Mode: Skip Let's Encrypt, just capture FQDN
    if [[ $lxdMode == "true" ]]; then
        set-FQDN-lxd
    fi
    
    # If version is 5.3 or lower do not prompt for QUIC
    version=($(echo "$takBinary" | grep -o -E '[0-9]+'))
    if [[ ${version[0]} -lt 6 ]]; then
        if [[ ${version[1]} -lt 4 ]]; then
            set-takConnector
        else
            takConnectorType="SSL" # TAK Server 5.4 enables QUIC by default
            # Apply the firewall rules for QUIC
            case $distro in
                rocky|rhel)
                    firewall-cmd --zone=public --add-port 8089/tcp --add-port 8090/udp --permanent >/dev/null
                    firewall-cmd --reload >/dev/null
                ;;
                ubuntu|debian)
                    ufw allow 8089 >/dev/null
                    ufw allow 8090/udp >/dev/null
                ;;
            esac
            connectorPort2="8090:quic" # Create the QUIC DP by default
        fi
    fi
    
    set-webTAKOptions
    finalize-install
}

# Establish the Execution Workflow
executeConfiguration(){
    clear
    
    apply-certproperties
    apply-certauthpass
    apply-certauthname
    apply-certautoenroll
    apply-takfederation
    apply-takConnector
    apply-webTAKOptions
    
    echo -e "${YELLOW}Configuring TAK Server for first run.${NC}"
    echo -e "\n# Configuring TAK Server for first run.\n" &>> $logfile
    touch $dir/logs/takserver-messaging.log
    chown -R tak:tak $dir
    
    # Enable and Start the TAK Server
    systemctl enable takserver && systemctl start takserver.service &
    ( tail -f -n0 $dir/logs/takserver-messaging.log & ) | grep -q "Started TAK Server messaging Microservice"
    echo -e "${GREEN}TAK Server service STARTED.${NC}" 2>&1 | tee -a $logfile
    
    # Create DataPackage
    if [[ $certAEnrollment = 0 ]]; then
        echo -e "${YELLOW}Creating Enrollment Datapackage.${NC}"
        echo -e "\n# Creating Enrollment Datapackage.\n" &>> $logfile
        create-datapackage
    else
        # Copy the Issuing CA
        echo -e "${YELLOW}Moving TAK Server Public Certificate.${NC}"
        echo -e "\n# Moving TAK Server Public Certificate.\n" &>> $logfile
        cp $certs/truststore-$intCA.p12 $homeDir/caCert.p12
        chown -R "$curuser":"$curuser" $homeDir
    fi
    
    # Create Webadmin Certificate
    create-webadmin
    
    case $distro in
        rocky|rhel)
            # Add the api firewall port
            firewall-cmd --zone=public --add-port 8443/tcp --permanent >/dev/null
            firewall-cmd --reload >/dev/null
        ;;
        ubuntu|debian)
            ufw allow 8443 >/dev/null
            ufw enable >/dev/null
        ;;
    esac
    
    usermod -aG tak $curuser
    clear
    
    if [[ $certAEnrollment = 0 ]]; then
        echo -e "${GREEN}Datapackages for $serverDesc copied to $homeDir${NC}" 2>&1 | tee -a $logfile
    else
        echo -e "${GREEN}TAK Server Public Certificate copied to $homeDir/caCert.p12${NC}" 2>&1 | tee -a $logfile
    fi
    
    cp $certs/ca.pem $homeDir/FedCA.pem
    echo -e "${GREEN}TAK Server Federation Hub Public Certificate copied to $homeDir/FedCA.pem${NC}" 2>&1 | tee -a $logfile
    echo -e "Web Admin Certificate copied to ${GREEN}$homeDir/webadmin.p12${NC}" 2>&1 | tee -a $logfile
    echo -e "Import the ${GREEN}webadmin.p12${NC} then navigate to the TAK Server UI: ${GREEN}https://$serverIP:8443${NC}" 2>&1 | tee -a $logfile
    echo -e "${GREEN}Initialization Complete.${NC}"
    
    postInstallVerification
}

#::::::::::
# Post-Install Verification for LXD Containers
#::::::::::
postInstallVerification(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying TAK Server installation...${NC}" 2>&1 | tee -a $logfile
        
        # Wait for TAK to start
        sleep 15
        
        # Check if takserver is running
        if systemctl is-active --quiet takserver; then
            echo -e "${GREEN}✓ TAK Server service is running${NC}" 2>&1 | tee -a $logfile
            
            # Check logs for successful startup
            if tail -n 50 /opt/tak/logs/takserver-messaging.log | grep -q "Started TAK Server"; then
                echo -e "${GREEN}✓ TAK Server started successfully${NC}" 2>&1 | tee -a $logfile
            else
                echo -e "${YELLOW}⚠ TAK Server running but startup may be incomplete${NC}" 2>&1 | tee -a $logfile
                echo -e "${YELLOW}Check logs: tail -f /opt/tak/logs/takserver-messaging.log${NC}" 2>&1 | tee -a $logfile
            fi
            
            # Verify PostgreSQL
            if ss -tulpn | grep -q ":5432"; then
                echo -e "${GREEN}✓ PostgreSQL is running${NC}" 2>&1 | tee -a $logfile
            else
                echo -e "${YELLOW}⚠ PostgreSQL may not be running${NC}" 2>&1 | tee -a $logfile
            fi
            
            # Verify ports are listening
            echo -e "${YELLOW}Checking TAK Server ports...${NC}" 2>&1 | tee -a $logfile
            ss -tulpn | grep -E ":8089|:8443|:8446" | tee -a $logfile
            
        else
            ERRoR="TAK Server failed to start. Check logs at /opt/tak/logs/takserver-messaging.log"
            abort
        fi
        
        echo -e "${GREEN}================================${NC}" 2>&1 | tee -a $logfile
        echo -e "${GREEN}TAK Server Installation Complete${NC}" 2>&1 | tee -a $logfile
        echo -e "${GREEN}================================${NC}" 2>&1 | tee -a $logfile
        echo -e "Web Admin: https://\$(hostname -f):8443" 2>&1 | tee -a $logfile
        echo -e "Admin Certificate: $homeDir/webadmin.p12" 2>&1 | tee -a $logfile
        
        if [[ $certAEnrollment = 0 ]]; then
            echo -e "Enrollment Package: $homeDir/enrollmentDP.zip" 2>&1 | tee -a $logfile
        else
            echo -e "CA Certificate: $homeDir/caCert.p12" 2>&1 | tee -a $logfile
        fi
        
        echo -e "" 2>&1 | tee -a $logfile
        echo -e "${YELLOW}IMPORTANT: Lets Encrypt SSL Setup${NC}" 2>&1 | tee -a $logfile
        echo -e "Lets Encrypt will be configured in Phase 5 (Networking)" 2>&1 | tee -a $logfile
        echo -e "Saved FQDN: $(cat /opt/tak/fqdn-for-letsencrypt.txt 2>/dev/null || echo 'Not set')" 2>&1 | tee -a $logfile
        echo -e "" 2>&1 | tee -a $logfile
        echo -e "Next Steps:" 2>&1 | tee -a $logfile
        echo -e "  1. Copy certificates to host: lxc file pull tak$homeDir/webadmin.p12 ~/" 2>&1 | tee -a $logfile
        echo -e "  2. Create snapshot: lxc snapshot tak tak-installed" 2>&1 | tee -a $logfile
        echo -e "  3. Proceed to Phase 4: Certificate Management" 2>&1 | tee -a $logfile
    fi
}

# Set FIPS Status
if [[ $fips =~ -(fip) ]]; then
        fips="true"
else
        fips="false"
fi

# Execute Script
verifyContainerNetworking

case $1 in
    *.rpm|*.deb)
        if [[ -f "$1" ]]; then
            # Determine if the user is root; else use sudo
            [ "$UID" -eq 0 ] || exec sudo "$0" "$@"
            
            backTitle="TAK Server Setup Wizard - Version: $sVER"
            type="OS"
            echo -e "${GREEN}Installation Type: TAK Server${NC}" >&2 | tee -a $logfile
            
            # Check for existing TAK Server installation
            case $distro in
                rocky|rhel)
                    if [[ $(dnf list installed | grep -wi 'takserver.noarch') ]]; then
                        echo -e "${RED}TAK Server already installed.${NC}" 2>&1 | tee -a $logfile
                        read -p "TAK Server already installed, Overwrite? (y/n) " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            status=$(systemctl is-active takserver)
                            if [ $status == "active" ]; then
                                systemctl stop takserver
                                echo -e "${GREEN}TAK Server service STOPPED.${NC}"
                            fi
                            dnf remove takserver -y 2>&1 | tee -a $logfile
                            echo -e "${GREEN}TAK Server successfully removed, continuing installation.${NC}"  2>&1 | tee -a $logfile
                        else
                            ERRoR="TAK Server already installed."
                            abort
                        fi
                    fi
                ;;
                ubuntu|debian)
                    if [[ $(apt list --installed | grep -wi 'takserver/now') ]]; then
                        echo -e "${RED}TAK Server already installed.${NC}" 2>&1 | tee -a $logfile
                        read -p "TAK Server already installed, Overwrite? (y/n) " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            status=$(systemctl is-active takserver)
                            if [ $status == "active" ]; then
                                systemctl stop takserver
                                echo -e "${GREEN}TAK Server service STOPPED.${NC}"
                            fi
                            apt-get remove takserver -y 2>&1 | tee -a $logfile
                            echo -e "${GREEN}TAK Server successfully removed, continuing installation.${NC}"  2>&1 | tee -a $logfile
                        else
                            ERRoR="TAK Server already installed."
                            abort
                        fi
                    fi 
                ;;
            esac
            
            # Conduct Prerequisite Checks
            prerequisite $1
            
            # Install TAK Server
            Install $1
            
            # Verify PostgreSQL for LXD
            verifyPostgreSQL
            
            # Run Setup Wizard
            takWizard
        else
            echo -e "${RED}ERROR: File not found: $1${NC}"
            echo "Usage: $0 <takserver.deb> [fips_mode] [lxd_mode]"
            echo "  fips_mode: true/false (default: false)"
            echo "  lxd_mode: true/false (default: false)"
            exit 1
        fi
    ;;
    *)
        echo "Usage: $0 <takserver.deb|takserver.rpm> [fips_mode] [lxd_mode]"
        echo "  fips_mode: true/false (default: false)"
        echo "  lxd_mode: true/false (default: false)"
        echo ""
        echo "Examples:"
        echo "  Normal install:     $0 takserver-5.5-RELEASE.deb"
        echo "  LXD container:      $0 takserver-5.5-RELEASE.deb false true"
        echo "  FIPS + LXD:         $0 takserver-5.5-RELEASE.deb true true"
        exit 1
    ;;
esac
