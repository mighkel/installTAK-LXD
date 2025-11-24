# Patch Notes - Version 2.5.1-LXD

## Bug Fix: Syntax Error on Line 665

**Issue:**
```bash
./installTAK-LXD-enhanced.sh: line 665: syntax error near unexpected token `('
./installTAK-LXD-enhanced.sh: line 665: `'"In LXD container mode, Let'"'"'s Encrypt SSL certificates...
```

**Root Cause:**
Complex nested quoting around apostrophes in dialog messages caused bash to misinterpret the quote boundaries.

**Fix:**
Simplified quoting by:
1. Removing apostrophe from "Let's Encrypt" → "Lets Encrypt" in dialog messages
2. Using standard double-quote format instead of nested quote concatenation
3. Removing unnecessary `\n` escape sequences (dialog handles newlines naturally)

**Files Modified:**
- `splash()` function - Simplified LXD mode welcome message
- `set-FQDN-lxd()` function - Fixed FQDN configuration dialog
- `finalize-install()` function - Simplified configuration summary
- `postInstallVerification()` function - Fixed completion messages

**Verification:**
Script now passes `bash -n` syntax check without errors.

---

## Changes from v2.5.0

### Dialog Messages
**Before:**
```bash
dialog ... --msgbox \
"IMPORTANT: Let's Encrypt Setup Deferred\n\n"'
'"In LXD container mode, Let'"'"'s Encrypt SSL certificates..." 0 0
```

**After:**
```bash
dialog ... --msgbox \
"IMPORTANT: Lets Encrypt Setup Deferred

In LXD container mode, Lets Encrypt SSL certificates..." 0 0
```

### Benefits:
- ✅ Script runs without syntax errors
- ✅ Cleaner, more readable code
- ✅ Easier to maintain
- ✅ Dialog messages display correctly
- ✅ No functionality changes

---

## Testing

### Syntax Check
```bash
bash -n installTAK-LXD-enhanced.sh
# Returns: (no output = success)
```

### Execution Test
```bash
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb false true
# Should start without syntax errors
```

---

## Installation

### Quick Update
If you already downloaded the script:

```bash
# In your container
cd ~/takserver-install/installTAK-LXD

# Download fixed version
wget https://raw.githubusercontent.com/mighkel/installTAK-LXD/main/scripts/installTAK-LXD-enhanced.sh -O installTAK-LXD-enhanced.sh

# Make executable
chmod +x installTAK-LXD-enhanced.sh

# Run installation
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb false true
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.5.1   | Nov 23, 2025 | Fixed syntax error in dialog quoting |
| 2.5.0   | Nov 22, 2025 | Initial LXD enhancement, Let's Encrypt deferral |

---

## Additional Notes

### About "Lets Encrypt" vs "Let's Encrypt"
In user-facing documentation and messages where the apostrophe doesn't cause issues, we still use the correct spelling "Let's Encrypt". Only in bash dialog messages within the script do we use "Lets Encrypt" to avoid quoting complications.

### Future Improvements
Consider migrating to a more robust dialog library (like whiptail) or using heredoc syntax for complex multi-line messages to avoid quoting issues entirely.

---

*Last Updated: November 23, 2025*
