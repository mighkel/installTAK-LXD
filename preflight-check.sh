#!/bin/bash
# Pre-flight check for installTAK-LXD-enhanced.sh
# Version: 1.0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "==================================="
echo "installTAK-LXD Pre-Flight Check"
echo "==================================="
echo ""

SCRIPT="installTAK-LXD-enhanced.sh"

# Check if script exists
echo -n "Checking if $SCRIPT exists... "
if [ -f "$SCRIPT" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo ""
    echo "Script not found. Please download it first:"
    echo "wget https://raw.githubusercontent.com/mighkel/installTAK-LXD/main/scripts/$SCRIPT"
    exit 1
fi

# Check if script is executable
echo -n "Checking if script is executable... "
if [ -x "$SCRIPT" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠${NC}"
    echo "Making script executable..."
    chmod +x "$SCRIPT"
    if [ -x "$SCRIPT" ]; then
        echo -e "${GREEN}✅ Fixed${NC}"
    else
        echo -e "${RED}❌ Could not make executable${NC}"
        exit 1
    fi
fi

# Check script syntax
echo -n "Checking script syntax... "
if bash -n "$SCRIPT" 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo ""
    echo "Syntax errors found in script:"
    bash -n "$SCRIPT"
    echo ""
    echo "Please download the latest version:"
    echo "wget https://raw.githubusercontent.com/mighkel/installTAK-LXD/main/scripts/$SCRIPT -O $SCRIPT"
    exit 1
fi

# Check for required TAK files
echo ""
echo "Checking for required TAK Server files..."

TAK_DEB=$(ls takserver-*.deb 2>/dev/null | head -n 1)
if [ -n "$TAK_DEB" ]; then
    echo -e "  TAK Server .deb: ${GREEN}✅ Found ($TAK_DEB)${NC}"
else
    echo -e "  TAK Server .deb: ${RED}❌ Not found${NC}"
    echo "    Download from https://tak.gov/"
fi

if [ -f "takserver-public-gpg.key" ]; then
    echo -e "  GPG Key: ${GREEN}✅ Found${NC}"
else
    echo -e "  GPG Key: ${RED}❌ Not found (takserver-public-gpg.key)${NC}"
    echo "    Download from https://tak.gov/"
fi

# Check if running as root
echo ""
echo -n "Checking if running as root... "
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠ You are root${NC}"
    echo "  Note: Script should be run as: sudo ./$SCRIPT"
else
    echo -e "${GREEN}✅ Not root (correct)${NC}"
fi

# Check for sudo access
echo -n "Checking sudo access... "
if sudo -n true 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠ Requires password${NC}"
    echo "  You'll be prompted for password when running script"
fi

# Check internet connectivity
echo -n "Checking internet connectivity... "
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo "  WARNING: No internet connectivity detected"
    echo "  Installation will fail without internet access"
fi

# Check DNS resolution
echo -n "Checking DNS resolution... "
if nslookup archive.ubuntu.com >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo "  WARNING: DNS resolution failing"
fi

# Check system memory
echo -n "Checking system memory... "
MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$MEM_TOTAL" -gt 7800000 ]; then
    MEM_GB=$((MEM_TOTAL / 1024 / 1024))
    echo -e "${GREEN}✅ ${MEM_GB}GB${NC}"
else
    MEM_GB=$((MEM_TOTAL / 1024 / 1024))
    echo -e "${RED}❌ ${MEM_GB}GB (minimum 8GB required)${NC}"
fi

# Check disk space
echo -n "Checking disk space... "
DISK_AVAIL=$(df / | tail -1 | awk '{print $4}')
DISK_GB=$((DISK_AVAIL / 1024 / 1024))
if [ "$DISK_AVAIL" -gt 10485760 ]; then  # 10GB in KB
    echo -e "${GREEN}✅ ${DISK_GB}GB available${NC}"
else
    echo -e "${YELLOW}⚠ ${DISK_GB}GB available (recommend 10GB+)${NC}"
fi

echo ""
echo "==================================="
echo "Pre-Flight Check Complete"
echo "==================================="
echo ""

# Check if TAK files present
if [ -z "$TAK_DEB" ] || [ ! -f "takserver-public-gpg.key" ]; then
    echo -e "${YELLOW}Missing TAK Server files${NC}"
    echo "Download required files before running installation."
    echo ""
    exit 1
fi

# Final verdict
SYNTAX_OK=$(bash -n "$SCRIPT" 2>/dev/null && echo "yes" || echo "no")
INTERNET_OK=$(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "yes" || echo "no")
MEM_OK=$([ "$MEM_TOTAL" -gt 7800000 ] && echo "yes" || echo "no")

if [ "$SYNTAX_OK" = "yes" ] && [ "$INTERNET_OK" = "yes" ] && [ "$MEM_OK" = "yes" ]; then
    echo -e "${GREEN}All checks passed! Ready to install.${NC}"
    echo ""
    echo "Run installation with:"
    echo -e "${GREEN}sudo ./$SCRIPT $TAK_DEB false true${NC}"
    echo "                                   ^^^^^ ^^^^^"
    echo "                                   FIPS  LXD Mode"
    echo ""
    exit 0
else
    echo -e "${RED}Some checks failed. Please fix issues before installing.${NC}"
    echo ""
    exit 1
fi
