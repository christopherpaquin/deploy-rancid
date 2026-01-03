# RANCID Operators Guide: Using Git to Review Switch Configurations

![Status](https://img.shields.io/badge/status-operational-success.svg)
![Audience](https://img.shields.io/badge/audience-operators-blue.svg)

This guide explains how operators use Git to review and compare network device configurations
managed by RANCID. This is a **read-only workflow** focused on viewing history and changes.

---

## 📋 Table of Contents

- [🎯 Purpose and Scope](#-purpose-and-scope)
- [🔑 Key Concepts](#-key-concepts)
- [📁 Example Environment](#-example-environment)
- [🚀 Getting Started](#-getting-started)
- [📊 Viewing Configuration History](#-viewing-configuration-history)
- [🔍 Understanding Git Diffs](#-understanding-git-diffs)
- [📈 Comparing Configurations](#-comparing-configurations)
- [💡 Operational Patterns](#-operational-patterns)
- [⚡ Quick Reference](#-quick-reference)
- [🐛 Troubleshooting](#-troubleshooting)

---

## 🎯 Purpose and Scope

### What This Guide Covers

This guide describes how operators use Git to:

- ✅ View how many configuration revisions exist for each device
- ✅ Review when changes occurred (timestamps)
- ✅ Compare revisions (diffs) of device configurations
- ✅ Extract historical configurations
- ✅ Understand what changed between backups

### What This Guide Does NOT Cover

- ❌ Software development workflows
- ❌ Manual editing or committing of files
- ❌ Git repository administration
- ❌ Advanced Git operations (branching, merging, etc.)

### Important Notes

- **RANCID automatically commits changes** when it detects configuration differences
- **Operators typically work in read-only mode** - viewing history, not creating it
- **Each device has one config file** that Git tracks over time
- **Git stores the complete history** with timestamps and change details

---

## 🔑 Key Concepts

### 1. One File Per Device

RANCID maintains a single "current" config file per device in the `configs/` directory:

```text
configs/
├── switch-1
├── switch-2
├── router-core-01
└── firewall-dmz-01
```

Each file contains the complete configuration for that device as retrieved by RANCID.

### 2. Git Holds the History

Each time RANCID detects a configuration change, it automatically commits a new revision to Git. Git stores:

- **The timestamp** (when the change was detected)
- **The changes** (what was added, removed, or modified)
- **The full revision history** (all previous versions)

### 3. Users Consume History; RANCID Produces It

**Normal operator workflow is read-only:**

- ✅ Operators inspect history and diffs
- ✅ Operators view configurations at specific points in time
- ✅ Operators compare different revisions
- ❌ Operators do NOT create commits (except in exceptional administrative cases)

---

## 📁 Example Environment

Throughout this guide, we'll use the following example:

- **RANCID group directory**: `/var/lib/rancid/core-switches/`
- **Config directory**: `/var/lib/rancid/core-switches/configs/`
- **Devices**: `switch-1`, `switch-2`, `router-core-01`

**All commands below are run from the RANCID group directory:**

```bash
cd /var/lib/rancid/core-switches
```

---

## 🚀 Getting Started

### A. Confirm You Are in a Git-Backed RANCID Group

**Command:**

```bash
git status
```

**Expected Output:**

```text
On branch main
nothing to commit, working tree clean
```

**What This Means:**

- ✅ You're in a Git repository
- ✅ The repository is properly initialized
- ✅ No manual `git init` is needed
- ✅ RANCID has been managing this directory

**If You See an Error:**

If you see `fatal: not a git repository`, the directory may not have been set up correctly. Contact your RANCID administrator.

### B. List Devices Under Management

**Command:**

```bash
ls -1 configs/
```

**Expected Output:**

```text
router-core-01
switch-1
switch-2
```

**What This Means:**

- Each file represents one network device
- The filename typically matches the device hostname
- These are the devices RANCID is monitoring

**Alternative (with details):**

```bash
ls -lh configs/
```

This shows file sizes and modification times, which can help identify recently updated devices.

---

## 📊 Viewing Configuration History

### C. See How Many Revisions Exist for Each Device

#### Method 1: Count Revisions for a Single Device

**Command:**

```bash
git rev-list --count HEAD -- configs/switch-1
```

**Expected Output:**

```text
42
```

**What This Means:**

- The device `switch-1` has **42 revisions** (configuration changes) in the Git history
- This number represents how many times RANCID detected a change and committed it
- Higher numbers indicate more frequent configuration changes

**Interpretation:**

- **Low count (1-5)**: Device configuration is very stable, rarely changes
- **Medium count (10-50)**: Normal operational changes, regular updates
- **High count (100+)**: Very active device, frequent configuration changes

#### Method 2: Count Revisions for All Devices

**Command:**

```bash
for device in configs/*; do
  device_name=$(basename "$device")
  count=$(git rev-list --count HEAD -- "$device")
  echo "$device_name: $count revisions"
done
```

**Expected Output:**

```text
router-core-01: 15 revisions
switch-1: 42 revisions
switch-2: 28 revisions
```

**What This Means:**

- Quick overview of configuration change frequency across all devices
- Helps identify which devices have the most change activity
- Useful for capacity planning and monitoring

### D. View the Revision History (Timeline) for Each Device

#### Basic History View

**Command:**

```bash
git log --follow --date=iso -- configs/switch-1
```

**Expected Output:**

```text
commit a8c41d2f3e4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d
Author: RANCID Automation <rancid@hostname>
Date:   2025-12-22 02:00:01 -0500

    rancid: switch-1 config change

commit b91fa20e1d2c3b4a5f6e7d8c9b0a1f2e3d4c5b6a
Author: RANCID Automation <rancid@hostname>
Date:   2025-12-10 02:00:01 -0500

    rancid: switch-1 config change

commit c72eb31f4e5d6c7b8a9f0e1d2c3b4a5f6e7d8c9e0
Author: RANCID Automation <rancid@hostname>
Date:   2025-11-28 02:00:01 -0500

    rancid: switch-1 config change
```

**What This Shows:**

- **Commit hash** (unique identifier): `a8c41d2f3e4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d`
- **Author**: Always "RANCID Automation" (automatic commits)
- **Date**: When RANCID detected the change
- **Message**: Standard RANCID commit message

#### Compact History View (Recommended)

**Command:**

```bash
git log --follow --date=iso --pretty=format:'%h  %ad  %s' -- configs/switch-1
```

**Expected Output:**

```text
a8c41d2  2025-12-22 02:00:01 -0500  rancid: switch-1 config change
b91fa20  2025-12-10 02:00:01 -0500  rancid: switch-1 config change
c72eb31  2025-11-28 02:00:01 -0500  rancid: switch-1 config change
d83fc42  2025-11-15 02:00:01 -0500  rancid: switch-1 config change
```

**What This Shows:**

- **Short commit hash** (`%h`): `a8c41d2` (first 7 characters, usually unique)
- **Date** (`%ad`): ISO format timestamp
- **Subject** (`%s`): Commit message

**Why This Format is Better:**

- ✅ More compact, easier to scan
- ✅ Shows key information at a glance
- ✅ Better for identifying specific revisions quickly

#### History with File Statistics

**Command:**

```bash
git log --follow --stat --date=iso -- configs/switch-1
```

**Expected Output:**

```text
commit a8c41d2f3e4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d
Date:   2025-12-22 02:00:01 -0500

    rancid: switch-1 config change

 configs/switch-1 | 15 insertions(+), 8 deletions(-)

commit b91fa20e1d2c3b4a5f6e7d8c9b0a1f2e3d4c5b6a
Date:   2025-12-10 02:00:01 -0500

    rancid: switch-1 config change

 configs/switch-1 | 3 insertions(+), 12 deletions(-)
```

**What This Shows:**

- **Lines changed**: How many lines were added/removed in each revision
- **Change magnitude**: Helps identify major vs. minor changes
- **Quick assessment**: Large changes (100+ lines) may need more careful review

### E. View the Current (Latest) Config as Stored by RANCID

**Command:**

```bash
less configs/switch-1
```

**Or with line numbers:**

```bash
less -N configs/switch-1
```

**What This Shows:**

- The **most recent configuration** retrieved by RANCID
- This is the "current state" as RANCID knows it
- Use arrow keys to navigate, `q` to quit

**Alternative Commands:**

```bash
# View with pagination
cat configs/switch-1 | less

# View first 50 lines
head -50 configs/switch-1

# View last 50 lines
tail -50 configs/switch-1

# Search for specific content
grep -i "interface" configs/switch-1
```

---

## 🔍 Understanding Git Diffs

### What is a Git Diff?

A **diff** (difference) shows what changed between two versions of a file. Git diffs use a standard format that shows:

- **Lines that were removed** (marked with `-`)
- **Lines that were added** (marked with `+`)
- **Context lines** (unchanged lines around the changes, for reference)

### Diff Format Explained

Here's an example diff output:

```diff
diff --git a/configs/switch-1 b/configs/switch-1
index 1234567..abcdefg 100644
--- a/configs/switch-1
+++ b/configs/switch-1
@@ -45,6 +45,7 @@ interface GigabitEthernet0/1
  description Uplink to Core
  switchport mode trunk
  switchport trunk allowed vlan 10,20,30
+ switchport trunk allowed vlan add 40
  spanning-tree portfast trunk
 !
 interface GigabitEthernet0/2
@@ -120,8 +121,9 @@ vlan 20
  name Sales
 !
 vlan 30
- name Engineering
+ name Engineering-Deprecated
 !
+vlan 40
+ name Marketing
 !
```

### Reading a Diff Line by Line

#### Header Information

```diff
diff --git a/configs/switch-1 b/configs/switch-1
index 1234567..abcdefg 100644
--- a/configs/switch-1
+++ b/configs/switch-1
```

- **`--- a/configs/switch-1`**: The "old" version (before changes)
- **`+++ b/configs/switch-1`**: The "new" version (after changes)
- **`index`**: Internal Git identifiers (can be ignored)

#### Hunk Headers

```diff
@@ -45,6 +45,7 @@ interface GigabitEthernet0/1
```

This line tells you:

- **`-45,6`**: In the old file, starting at line 45, showing 6 lines of context
- **`+45,7`**: In the new file, starting at line 45, showing 7 lines (one line was added)
- **`interface GigabitEthernet0/1`**: Context - what section this change is in

#### Change Markers

- **Lines starting with `` ` `` (space)**: Unchanged context lines (for reference)
- **Lines starting with `-`**: Removed lines (present in old version, not in new)
- **Lines starting with `+`**: Added lines (not in old version, present in new)

#### Example Interpretation

```diff
  switchport trunk allowed vlan 10,20,30
+ switchport trunk allowed vlan add 40
```

**What happened:**

- The existing line `switchport trunk allowed vlan 10,20,30` remained unchanged
- A new line `switchport trunk allowed vlan add 40` was **added** (marked with `+`)
- This adds VLAN 40 to the allowed VLANs list

```diff
- name Engineering
+ name Engineering-Deprecated
```

**What happened:**

- The line `name Engineering` was **removed** (marked with `-`)
- The line `name Engineering-Deprecated` was **added** (marked with `+`)
- This is a **modification**: the VLAN name was changed

### Common Diff Patterns

#### 1. Adding Configuration

```diff
+ vlan 40
+ name Marketing
```

**Meaning**: New VLAN 40 was added with name "Marketing"

#### 2. Removing Configuration

```diff
- vlan 50
- name Old-Department
```

**Meaning**: VLAN 50 and its name were removed

#### 3. Modifying Configuration

```diff
- ip address 192.168.1.1 255.255.255.0
+ ip address 192.168.1.2 255.255.255.0
```

**Meaning**: IP address changed from 192.168.1.1 to 192.168.1.2

#### 4. Reordering (Less Common)

Sometimes lines are reordered. Git may show this as a removal and addition:

```diff
- line B
  line A
+ line B
  line C
```

**Meaning**: Line B was moved to a different position

### Diff Statistics

To see a summary of changes without the full diff:

```bash
git diff --stat <old_commit> <new_commit> -- configs/switch-1
```

**Output:**

```text
 configs/switch-1 | 15 insertions(+), 8 deletions(-)
```

**Meaning:**

- **15 insertions**: 15 lines were added
- **8 deletions**: 8 lines were removed
- **Net change**: +7 lines (file grew by 7 lines)

---

## 📈 Comparing Configurations

### F. Compare Two Revisions of a Device Config

There are several ways to compare configurations, depending on what you need.

#### Method 1: Compare Latest vs. Previous (Most Common)

**Command:**

```bash
git diff HEAD~1 HEAD -- configs/switch-1
```

**What This Does:**

- **`HEAD`**: The most recent commit (latest revision)
- **`HEAD~1`**: The commit immediately before HEAD (previous revision)
- Shows what changed in the most recent update

**Expected Output:**

```diff
diff --git a/configs/switch-1 b/configs/switch-1
index abc123..def456 100644
--- a/configs/switch-1
+++ b/configs/switch-1
@@ -45,6 +45,7 @@ interface GigabitEthernet0/1
  description Uplink to Core
  switchport mode trunk
  switchport trunk allowed vlan 10,20,30
+ switchport trunk allowed vlan add 40
  spanning-tree portfast trunk
```

**When to Use:**

- ✅ Quick check of the most recent change
- ✅ Reviewing what RANCID detected in the last run
- ✅ Verifying expected changes

**Limitation:**

If the most recent commit did not touch that specific file, this will show nothing. In that case, use Method 2.

#### Method 2: Compare Two Known Revision IDs (Most Reliable)

##### Step 1: Get the commit IDs

```bash
git log --pretty=format:'%h  %ad  %s' --date=iso -- configs/switch-1
```

**Output:**

```text
a8c41d2  2025-12-22 02:00:01 -0500  rancid: switch-1 config change
b91fa20  2025-12-10 02:00:01 -0500  rancid: switch-1 config change
c72eb31  2025-11-28 02:00:01 -0500  rancid: switch-1 config change
```

##### Step 2: Compare two specific commits

```bash
git diff b91fa20 a8c41d2 -- configs/switch-1
```

**What This Does:**

- Compares commit `b91fa20` (older) to commit `a8c41d2` (newer)
- Shows all changes between those two specific points in time
- Works regardless of what the most recent commit was

**When to Use:**

- ✅ Comparing specific historical revisions
- ✅ Investigating changes between two known dates
- ✅ Most reliable method for any comparison

#### Method 3: Compare Current Working File to Last Commit

**Command:**

```bash
git diff -- configs/switch-1
```

**What This Does:**

- Compares the current file on disk to the last committed version
- Shows uncommitted changes (if any)

**Expected Output (Normal Operation):**

```text
(empty - no output)
```

**What This Means:**

- ✅ No uncommitted changes
- ✅ File matches the last commit
- ✅ RANCID is working normally

**If You See Changes:**

- ⚠️ RANCID may have retrieved a new config but not yet committed it
- ⚠️ Manual edits may have been made (should be investigated)
- ⚠️ File may be in an inconsistent state

#### Method 4: Compare to a Specific Date

**Command:**

```bash
# Find commits before a specific date
git log --until="2025-12-01" --pretty=format:'%h' -- configs/switch-1 | head -1

# Then use that commit hash in a diff
git diff <commit_hash> HEAD -- configs/switch-1
```

**When to Use:**

- ✅ "What changed since December 1st?"
- ✅ Comparing current state to a specific point in time
- ✅ Reviewing changes over a time period

### G. Extract (Print) the Config From a Specific Revision

**Command:**

```bash
git show a8c41d2:configs/switch-1 | less
```

**What This Does:**

- Extracts the complete configuration file as it existed at commit `a8c41d2`
- Shows the full file, not just the changes
- Pipes to `less` for easy viewing

**Alternative (save to file):**

```bash
git show a8c41d2:configs/switch-1 > /tmp/switch-1-backup-2025-12-22.txt
```

**When to Use:**

- ✅ "What did the config look like before the change?"
- ✅ Extracting a historical backup
- ✅ Comparing full files side-by-side
- ✅ Recovery scenarios

**Example Workflow:**

```bash
# 1. View current config
less configs/switch-1

# 2. See what changed recently
git log --pretty=format:'%h  %ad' --date=iso -5 -- configs/switch-1

# 3. Extract config from before the change
git show b91fa20:configs/switch-1 > /tmp/switch-1-before.txt

# 4. Compare side-by-side (if you have diff tool)
diff -u /tmp/switch-1-before.txt configs/switch-1
```

### H. View Changes in a Specific Time Range

**Command:**

```bash
git log --since="2025-12-01" --until="2025-12-31" \
  --pretty=format:'%h  %ad  %s' --date=iso -- configs/switch-1
```

**What This Shows:**

- All commits for the device in December 2025
- Useful for monthly/quarterly change reviews
- Helps identify change patterns

**Output:**

```text
a8c41d2  2025-12-22 02:00:01 -0500  rancid: switch-1 config change
b91fa20  2025-12-10 02:00:01 -0500  rancid: switch-1 config change
```

### I. Find When a Specific Configuration Line Was Added or Changed

**Command:**

```bash
git log -p -S "vlan 40" -- configs/switch-1
```

**What This Does:**

- Searches for commits that added, removed, or modified the line containing "vlan 40"
- Shows the full diff for each matching commit
- Useful for tracking when specific configurations were introduced

**Output:**

```diff
commit a8c41d2f3e4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d
Date:   2025-12-22 02:00:01 -0500

    rancid: switch-1 config change

diff --git a/configs/switch-1 b/configs/switch-1
index abc123..def456 100644
--- a/configs/switch-1
+++ b/configs/switch-1
@@ -120,0 +121,2 @@
+vlan 40
+ name Marketing
```

**When to Use:**

- ✅ "When was VLAN 40 added?"
- ✅ "When did the IP address change?"
- ✅ Tracking specific configuration elements

---

## 💡 Operational Patterns

### Pattern 1: Daily Change Review

**Scenario**: Check what changed in the last 24 hours

**Commands:**

```bash
# See recent changes
git log --since="1 day ago" --pretty=format:'%h  %ad  %s' --date=iso

# For each changed device, view the diff
git log --since="1 day ago" --name-only --pretty=format:'' | sort -u | \
  while read file; do
  if [[ -f "$file" ]]; then
    echo "=== Changes in $file ==="
    git diff HEAD~1 HEAD -- "$file"
  fi
done
```

### Pattern 2: Investigating a Problem

**Scenario**: Device is misbehaving, need to see what changed recently

**Commands:**

```bash
# 1. List recent changes for the device
git log -10 --pretty=format:'%h  %ad  %s' --date=iso -- configs/switch-1

# 2. Compare last 3 revisions
git diff HEAD~3 HEAD -- configs/switch-1

# 3. Extract config from before the problem started
git show HEAD~3:configs/switch-1 > /tmp/switch-1-before-problem.txt

# 4. Compare to current
diff -u /tmp/switch-1-before-problem.txt configs/switch-1
```

### Pattern 3: Monthly Change Report

**Scenario**: Generate a summary of all changes in the past month

**Commands:**

```bash
# Count changes per device
for device in configs/*; do
  device_name=$(basename "$device")
  count=$(git log --since="1 month ago" --oneline -- "$device" | wc -l)
  if [[ $count -gt 0 ]]; then
    echo "$device_name: $count changes"
  fi
done

# Show summary of changes
git log --since="1 month ago" --stat --pretty=format:'%h  %ad  %s' --date=iso
```

### Pattern 4: Finding When a Configuration Was Removed

**Scenario**: A configuration line is missing, need to find when it was removed

**Commands:**

```bash
# Search for when a line containing "missing-config" was removed
git log -p -S "missing-config" --all -- configs/switch-1

# Or search for when it last appeared
git log --all --full-history -S "missing-config" -- configs/switch-1 | head -1
```

### Important Operational Notes

#### 1. Config Changes Only Create Revisions When They Actually Change

**Key Point**: RANCID runs on a schedule (typically nightly), but it only commits when:

- The retrieved config **differs** from the last stored revision
- This is why "revision count" maps to "number of config changes," not "number of runs"

**Implication**: If a device shows 10 revisions over 30 days, it means:
- RANCID ran 30 times (once per day)
- But only 10 of those runs detected actual configuration changes
- The device was stable for 20 of those days

#### 2. Use Commit History as Your "Timestamped Backups"

**Key Point**: Each commit is equivalent to a timestamped backup file

- The commit date is the "backup date"
- You can extract any historical version
- Git provides the backup mechanism automatically

**Implication**: No need to manually create backup files - Git already has them all.

#### 3. Avoid Manual Commits

**Key Point**: Operators should generally NOT:

- ❌ Edit files in `configs/`
- ❌ Commit changes manually
- ❌ Rewrite history
- ❌ Force push

**Exception**: Break-glass operations (documented, exceptional administrative cases)

**Why**: RANCID manages these files automatically. Manual edits can cause:
- Conflicts with RANCID's next run
- Inconsistent state
- Loss of automatic change tracking

---

## ⚡ Quick Reference

### Essential Commands

#### Count Revisions

```bash
git rev-list --count HEAD -- configs/switch-1
```

#### Show History

```bash
git log --date=iso --pretty=format:'%h %ad %s' -- configs/switch-1
```

#### Compare Revisions

```bash
git diff <old_commit> <new_commit> -- configs/switch-1
```

#### View Config at Revision

```bash
git show <commit>:configs/switch-1 | less
```

#### Compare Latest to Previous

```bash
git diff HEAD~1 HEAD -- configs/switch-1
```

#### Find Changes in Time Range

```bash
git log --since="2025-12-01" --until="2025-12-31" -- configs/switch-1
```

#### Search for Specific Configuration

```bash
git log -p -S "search-text" -- configs/switch-1
```

### Common Workflows

#### "What changed today?"

```bash
git log --since="today" --pretty=format:'%h %ad %s' --date=iso
git diff HEAD~1 HEAD
```

#### "Show me the last 5 changes for this device"

```bash
git log -5 --pretty=format:'%h %ad %s' --date=iso -- configs/switch-1
```

#### "What did the config look like 2 weeks ago?"

```bash
# Find commit from 2 weeks ago
COMMIT=$(git log --until="2 weeks ago" --pretty=format:'%h' \
  -- configs/switch-1 | head -1)

# View that config
git show $COMMIT:configs/switch-1 | less
```

#### "Show me all devices that changed this week"

```bash
git log --since="1 week ago" --name-only --pretty=format:'' | \
  grep "^configs/" | sort -u
```

---

## 🐛 Troubleshooting

### Issue: "fatal: not a git repository"

**Symptoms:**

```bash
$ git status
fatal: not a git repository
```

**Possible Causes:**

1. Not in the RANCID group directory
2. Git repository was not initialized
3. Directory structure is incorrect

**Solutions:**

```bash
# Verify you're in the right directory
pwd
# Should show: /var/lib/rancid/<group-name>

# Check if .git directory exists
ls -la .git

# If missing, contact RANCID administrator
```

### Issue: "No revisions found" or "Count is 0"

**Symptoms:**

```bash
$ git rev-list --count HEAD -- configs/switch-1
0
```

**Possible Causes:**

1. Device was just added (no changes detected yet)
2. RANCID hasn't run yet
3. File doesn't exist

**Solutions:**

```bash
# Check if file exists
ls -l configs/switch-1

# Check Git history
git log --all -- configs/switch-1

# Verify RANCID is running
systemctl status rancid
```

### Issue: "Diff shows no changes"

**Symptoms:**

```bash
$ git diff HEAD~1 HEAD -- configs/switch-1
(no output)
```

**Possible Causes:**

1. Most recent commit didn't change this file
2. Comparing identical revisions
3. File wasn't modified in that commit

**Solutions:**

```bash
# Verify the commit actually touched this file
git show --name-only HEAD

# Find the last commit that changed this file
git log -1 -- configs/switch-1

# Compare to that commit instead
git diff <last_commit>~1 <last_commit> -- configs/switch-1
```

### Issue: "Too many changes in diff"

**Symptoms:** Diff output is overwhelming, hundreds of lines

**Solutions:**

```bash
# Use --stat for summary only
git diff --stat <old> <new> -- configs/switch-1

# View diff with pager (use space to scroll, q to quit)
git diff <old> <new> -- configs/switch-1 | less

# Save to file for review
git diff <old> <new> -- configs/switch-1 > /tmp/changes.txt
less /tmp/changes.txt
```

### Issue: "Can't find a specific commit"

**Symptoms:** Commit hash doesn't work or can't be found

**Solutions:**

```bash
# Use shorter hash (first 7 characters usually work)
git show a8c41d2:configs/switch-1

# Search by date instead
git log --until="2025-12-22" --pretty=format:'%h' -- configs/switch-1 | head -1

# List all commits to find the right one
git log --oneline -- configs/switch-1
```

### Issue: "Understanding a complex diff"

**Symptoms:** Diff is hard to read, many changes

**Tips:**

1. **Use side-by-side view** (if available):

   ```bash
   git diff --word-diff <old> <new> -- configs/switch-1
   ```

2. **Focus on specific sections**:

   ```bash
   # Extract both versions and compare manually
   git show <old>:configs/switch-1 > /tmp/old.txt
   git show <new>:configs/switch-1 > /tmp/new.txt
   diff -u /tmp/old.txt /tmp/new.txt | less
   ```

3. **Use graphical tools** (if available):

   ```bash
   git difftool <old> <new> -- configs/switch-1
   ```

---

## 📚 Additional Resources

### Git Documentation

- **Git Basics**: `man git` or `git help`
- **Git Log**: `git help log`
- **Git Diff**: `git help diff`
- **Git Show**: `git help show`

### RANCID Documentation

- **RANCID Manual**: `man rancid`
- **RANCID Configuration**: `/usr/share/doc/rancid/`
- **Project README**: `README.md` in this repository

### Getting Help

If you encounter issues not covered in this guide:

1. Review the troubleshooting section above
2. Check RANCID logs: `/var/lib/rancid/<group>/logs/`
3. Consult your RANCID administrator
4. Review Git documentation for advanced operations

---

**Last Updated**: 2025-01-03
