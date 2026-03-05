# Manual Testing Guide

This guide provides step-by-step recipes for manually testing KnoxTrain functionality without running the full test suite.

## Prerequisites

```bash
# Ensure you can run knox from source
ruby -I lib exe/knox version

# Expected output: knox 0.8.0 (or current version)
```

---

## 1. Configuration Validation

### Test: Valid Config Loads

```bash
ruby -I lib exe/knox validate -c restic/knox_train.rb
```

Expected: Config valid message with profiles and groups listed.

### Test: Invalid Config Fails

```bash
# Create invalid config
cat > /tmp/bad-config.rb << 'EOF'
profile :test do
  sources ["~/Documents"]

  backend :invalid_backend do
    repo "s3://bucket"
    invalid_option "value"  # This should cause error
  end
end
EOF

ruby -I lib exe/knox validate -c /tmp/bad-config.rb
```

Expected: UnknownKeyError for `invalid_option`.

### Test: Show Profile Config

```bash
ruby -I lib exe/knox show documents -c restic/knox_train.rb
```

Expected: Full resolved configuration for the `documents` profile (sources, backends, tags, etc.).

---

## 2. Backup Operations

### Test: Dry Run (Validation Only)

```bash
# This validates config without touching restic
ruby -I lib exe/knox validate -c restic/knox_train.rb
```

### Test: Single Backend Backup (if restic installed)

```bash
# Backup one profile to one backend
ruby -I lib exe/knox backup -p documents -b s3 -c restic/knox_train.rb
```

Expected: Command attempts restic execution (or gracefully handles missing restic/credentials).

### Test: All Backends (if restic installed)

```bash
# Backup all profiles and backends
ruby -I lib exe/knox backup --all -c restic/knox_train.rb
```

### Test: Backup with Pruning

```bash
# Apply retention policy after backup
ruby -I lib exe/knox backup --all --prune -c restic/knox_train.rb
```

### Test: Profile Not Found

```bash
ruby -I lib exe/knox backup -p nonexistent -c restic/knox_train.rb
```

Expected: Error message "Profile 'nonexistent' not found."

### Test: Missing Profile Flag

```bash
ruby -I lib exe/knox backup -c restic/knox_train.rb
```

Expected: Error "Specify --profile NAME or --all".

---

## 3. Status Reporting

### Test: Status Table

```bash
ruby -I lib exe/knox status -c restic/knox_train.rb
```

Expected: Table showing profile, backend, snapshot count, latest time, file count, restore size, stored size, dedup ratio.

### Test: Status Verbose Output

```bash
ruby -I lib exe/knox status -v -c restic/knox_train.rb
```

Expected: Detailed JSON snapshots, stats (restore size), and stats (raw/dedup).

### Test: Filter by Backend

```bash
ruby -I lib exe/knox status -b s3 -c restic/knox_train.rb
```

Expected: Only S3 backends shown in table.

---

## 4. Launchd Scheduling (macOS Only)

### 4a. Install Schedule

**Setup:** Calculate time 5 minutes in future:

```bash
HOUR=$(date +%H)
MIN=$(( $(date +%M) + 5 ))
if [ $MIN -ge 60 ]; then
  HOUR=$(( HOUR + 1 ))
  MIN=$(( MIN - 60 ))
fi
TIME=$(printf "%02d:%02d" $HOUR $MIN)
echo "Scheduling for: $TIME"
```

**Test: Install Schedule**

```bash
ruby -I lib exe/knox schedule --all --time "$TIME" -c restic/knox_train.rb
```

Expected: "✓ Scheduled: ~/Library/LaunchAgents/local.kt.all.backup.plist" + notification.

**Verify Installation:**

```bash
# Check plist exists
ls -la ~/Library/LaunchAgents/local.kt.all.backup.plist

# View plist contents
cat ~/Library/LaunchAgents/local.kt.all.backup.plist

# Check launchctl sees it
launchctl list | grep local.kt.all.backup

# Check it's enabled
launchctl print user/$(id -u)/local.kt.all.backup 2>/dev/null | head -20
```

### 4b. Invalid Time Format

```bash
ruby -I lib exe/knox schedule --all --time 25:00 -c restic/knox_train.rb
```

Expected: Error "Specify --time HH:MM, hour 0-23".

### 4c. Missing --all Flag

```bash
ruby -I lib exe/knox schedule --time 02:00 -c restic/knox_train.rb
```

Expected: Error "Specify --all (per-profile scheduling not yet supported)".

### 4d. Manual Trigger (Test Execution)

```bash
# Start the scheduled backup immediately (don't wait for scheduled time)
launchctl start local.kt.all.backup

# Watch the log in real-time
tail -f ~/Library/Logs/knox/backup.log

# In another terminal, check backup completed
sleep 2
launchctl list | grep local.kt.all.backup
```

Expected: Backup runs immediately, logs appear in `~/Library/Logs/knox/backup.log`.

### 4e. Unschedule

```bash
ruby -I lib exe/knox unschedule --all -c restic/knox_train.rb
```

Expected: "✓ Unscheduled: ~/Library/LaunchAgents/local.kt.all.backup.plist" + notification.

**Verify Removal:**

```bash
ls ~/Library/LaunchAgents/local.kt.all.backup.plist 2>&1
# Expected: "No such file or directory"

launchctl list | grep local.kt.all.backup
# Expected: (no output)
```

### 4f. Idempotent Install (Re-scheduling)

```bash
# Install at one time
ruby -I lib exe/knox schedule --all --time 02:00 -c restic/knox_train.rb

# Change to different time (should unload, then reload)
ruby -I lib exe/knox schedule --all --time 03:00 -c restic/knox_train.rb

# Verify only one plist exists
launchctl list | grep local.kt.all.backup | wc -l
# Expected: 1
```

### 4g. Unschedule When Not Scheduled

```bash
# Ensure it's unscheduled first
ruby -I lib exe/knox unschedule --all -c restic/knox_train.rb

# Try to unschedule again
ruby -I lib exe/knox unschedule --all -c restic/knox_train.rb
```

Expected: Yellow warning "Not scheduled (plist not found)" — no error.

---

## 5. Notifications Testing

### 5a. Notifications Enabled (Default)

```bash
cat > /tmp/notify-enabled.rb << 'EOF'
global do
  notifications true
end

profile :test do
  sources ["~/Documents"]
  backend :s3 do
    repo "s3://bucket"
    password { "pwd" }
  end
end
EOF

ruby -I lib exe/knox schedule --all --time 14:30 -c /tmp/notify-enabled.rb
```

Expected: macOS notification appears: "✓ Scheduled daily backup at 14:30"

### 5b. Notifications Disabled

```bash
cat > /tmp/notify-disabled.rb << 'EOF'
global do
  notifications false
end

profile :test do
  sources ["~/Documents"]
  backend :s3 do
    repo "s3://bucket"
    password { "pwd" }
  end
end
EOF

ruby -I lib exe/knox schedule --all --time 14:30 -c /tmp/notify-disabled.rb
```

Expected: No notification appears.

### 5c. Backup Success Notification

When restic is available and backup succeeds:

```bash
ruby -I lib exe/knox backup --all -c restic/knox_train.rb
# (wait for completion)
```

Expected: macOS notification "✓ Backup complete: all backends succeeded"

### 5d. Backup Failure Notification

When restic fails (e.g., bad credentials):

```bash
cat > /tmp/bad-creds.rb << 'EOF'
global do
  notifications true
end

profile :test do
  sources ["~/Documents"]
  backend :sftp do
    repo "sftp://invalid.host/path"
    password { "wrong-password" }
  end
end
EOF

ruby -I lib exe/knox backup --all -c /tmp/bad-creds.rb
```

Expected: macOS notification with activation: "⚠️  Backup incomplete: some backends failed. Check logs."

---

## 6. Secrets Management

### 6a. Keychain Access (macOS)

**Setup:** Add test secret to keychain:

```bash
security add-generic-password -s "test-restic-pw" -a "" -w "my-secret-password"
```

**Test: Retrieve from Keychain**

```bash
cat > /tmp/keychain-test.rb << 'EOF'
global { notifications false }

profile :test do
  sources ["~/Documents"]
  backend :s3 do
    repo "s3://bucket"
    password { keychain("test-restic-pw") }
  end
end
EOF

ruby -I lib exe/knox show test -c /tmp/keychain-test.rb
```

Expected: Config loads successfully (password shows as "[block]").

### 6b. Environment Variable Fallback

**Setup:**

```bash
export TEST_RESTIC_PW="env-password"
```

**Test:**

```bash
cat > /tmp/env-test.rb << 'EOF'
global { notifications false }

profile :test do
  sources ["~/Documents"]
  backend :s3 do
    repo "s3://bucket"
    password { env_secret("TEST_RESTIC_PW") }
  end
end
EOF

ruby -I lib exe/knox show test -c /tmp/env-test.rb
```

Expected: Config loads successfully.

### 6c. env_credential Setup

```bash
cat > /tmp/cred-test.rb << 'EOF'
global { notifications false }

profile :test do
  sources ["~/Documents"]
  backend :s3 do
    repo "s3://bucket"
    password { keychain("s3-password") }
    env_credential("AWS_ACCESS_KEY_ID") { keychain("s3-access-key") }
    env_credential("AWS_SECRET_ACCESS_KEY") { keychain("s3-secret-key") }
  end
end
EOF

ruby -I lib exe/knox show test -c /tmp/cred-test.rb
```

Expected: Shows env_credentials in backend config.

---

## 7. SSH/SshServer Testing

### 7a. Wake-on-LAN

**Setup:** Know target MAC address (e.g., `00:11:22:33:44:55`)

```bash
# Power off the device first
# Then test WoL:
ruby -I lib -e "
require 'knox_train'
server = KnoxTrain::SshServer.new('nas.local', mac: '00:11:22:33:44:55')
puts 'Sending WoL...'
server.wake
puts 'WoL sent'
sleep 10
puts \"Online? #{server.online?}\"
"
```

Expected: Device powers on within 10 seconds.

### 7b. Online Check

```bash
ruby -I lib -e "
require 'knox_train'
server = KnoxTrain::SshServer.new('192.168.1.100')
puts \"Online? #{server.online?}\"
"
```

Expected: true/false based on ping success.

### 7c. Run Hooks in Config

```bash
cat > /tmp/hooks-test.rb << 'EOF'
global { notifications false }

profile :test do
  sources ["~/Documents"]
  tags [:test]
  host "nas.local"

  backend :sftp do
    repo "sftp://nas.local/backups/test"
    password { "test" }

    run_before do
      puts "[HOOK] Before: Waking NAS"
      # server = SshServer.new("nas.local", mac: "...")
      # server.wake
    end

    run_after do
      puts "[HOOK] After: Shutting down NAS"
      # server = SshServer.new("nas.local", mac: "...")
      # server.shutdown
    end
  end
end
EOF

ruby -I lib exe/knox backup -p test -b sftp -c /tmp/hooks-test.rb 2>&1 | grep HOOK
```

Expected: Hook messages appear in output.

---

## 8. Error Scenarios

### 8a. Skip Profile (Missing Conditional Source)

```bash
cat > /tmp/skip-test.rb << 'EOF'
global { notifications false }

profile :external do
  sources [
    proc do
      path = "/Volumes/nonexistent/photos"
      unless File.directory?(path)
        skip! "External drive not mounted"
      end
      path
    end
  ]

  backend :s3 do
    repo "s3://bucket"
    password { "pwd" }
  end
end
EOF

ruby -I lib exe/knox backup -p external -c /tmp/skip-test.rb
```

Expected: Yellow warning "Skipping external: External drive not mounted" — continues gracefully.

### 8b. Config File Not Found

```bash
ruby -I lib exe/knox backup --all -c /nonexistent/config.rb
```

Expected: Red error "No config file found. Use -c PATH to specify."

### 8c. Invalid YAML/Ruby Syntax

```bash
cat > /tmp/syntax-error.rb << 'EOF'
profile :test do
  sources ["~/Documents"
  # Missing closing bracket
end
EOF

ruby -I lib exe/knox validate -c /tmp/syntax-error.rb
```

Expected: Ruby syntax error.

---

## 9. Integration Test (Full Workflow)

Complete workflow testing:

```bash
#!/bin/bash
set -e

echo "=== 1. Validate config ==="
ruby -I lib exe/knox validate -c restic/knox_train.rb

echo ""
echo "=== 2. Show profile ==="
ruby -I lib exe/knox show documents -c restic/knox_train.rb | head -10

echo ""
echo "=== 3. Check status ==="
ruby -I lib exe/knox status -c restic/knox_train.rb || true

echo ""
echo "=== 4. Schedule backup (for 5 min from now) ==="
HOUR=$(date +%H)
MIN=$(( $(date +%M) + 5 ))
if [ $MIN -ge 60 ]; then
  HOUR=$(( HOUR + 1 ))
  MIN=$(( MIN - 60 ))
fi
TIME=$(printf "%02d:%02d" $HOUR $MIN)

ruby -I lib exe/knox schedule --all --time "$TIME" -c restic/knox_train.rb

echo ""
echo "=== 5. Verify plist installed ==="
ls -la ~/Library/LaunchAgents/local.kt.all.backup.plist

echo ""
echo "=== 6. Check launchctl status ==="
launchctl list | grep local.kt.all.backup

echo ""
echo "=== 7. Manually trigger backup ==="
launchctl start local.kt.all.backup 2>&1 || true

echo ""
echo "=== 8. View logs ==="
tail -5 ~/Library/Logs/knox/backup.log 2>/dev/null || echo "(No logs yet)"

echo ""
echo "=== 9. Unschedule ==="
ruby -I lib exe/knox unschedule --all -c restic/knox_train.rb

echo ""
echo "=== 10. Verify plist removed ==="
ls ~/Library/LaunchAgents/local.kt.all.backup.plist 2>&1 || echo "✓ Plist removed"

echo ""
echo "=== Integration test complete ==="
```

Save as `test-workflow.sh`, then:

```bash
chmod +x test-workflow.sh
./test-workflow.sh
```

---

## 10. Debugging Tips

### View Plist Content

```bash
cat ~/Library/LaunchAgents/local.kt.all.backup.plist
```

### Check Launchd Logs

```bash
# System-wide launchd logs
log stream --predicate 'eventMessage contains "local.kt"' --level debug

# Or check Console.app
open /Applications/Utilities/Console.app
```

### Test Ruby Directly

```bash
ruby -I lib << 'EOF'
require 'knox_train'
require 'knox_train/cli'

config_path = File.expand_path('restic/knox_train.rb')
KnoxTrain::ConfigLoader.load(config_path)
registry = KnoxTrain.registry

puts "Profiles: #{registry.profiles.keys}"
registry.profiles.each do |name, profile|
  puts "  #{name}: #{profile.backends.length} backends"
  profile.backends.each { |b| puts "    - #{b.type}" }
end
EOF
```

### Inspect Notifications Module

```bash
ruby -I lib << 'EOF'
require 'knox_train/notifications'

puts "OS: #{OS.mac? ? 'macOS' : 'non-macOS'}"
puts "Notifications available: #{KnoxTrain::Notifications.instance_methods.include?(:notify!)}"

# Test notify! (will show notification on macOS)
KnoxTrain::Notifications.module_eval do
  extend self
  notify!("Test notification", { title: "KnoxTrain Test" })
end
EOF
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| `security` command not found | Install Xcode Command Line Tools: `xcode-select --install` |
| Keychain password not found | Add it: `security add-generic-password -s "service-name" -a "" -w "password"` |
| Launchd plist permissions wrong | Uninstall, re-install: `knox unschedule --all && knox schedule --all --time HH:MM` |
| Logs not appearing | Check `/Users/$(whoami)/Library/Logs/knox/` — may need to create `~/.config/restic/` directories |
| Restic command not found | Install restic: `brew install restic` |
| Notifications not appearing | Check `global { notifications }` is true; macOS only (non-macOS is silent) |

