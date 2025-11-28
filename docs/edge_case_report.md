# Edge Case Report: Local/Database Synchronization

## Overview
This report documents all edge cases handled in the bidirectional sync system between local device storage (SharedPreferences) and the Supabase database for the Yuh Blockin' app.

---

## Edge Cases Handled

### 1. Database Deleted, Local Storage Exists
**Scenario:** User deletes their plates from the database (via Supabase dashboard, API, or another device), but the app still shows plates locally.

**Risk:** User sees "ghost" plates that no longer exist in the system. Alerts sent to these plates would fail.

**Solution:**
- On app startup, `syncWithDatabase()` compares local plates against DB plates
- Any local plate NOT found in DB is removed from local storage
- User sees accurate, up-to-date plate list

**Code Location:** `plate_storage_service.dart:syncWithDatabase()`

---

### 2. Local Storage Empty, Database Has Plates
**Scenario:** User reinstalls app or clears app data, losing local storage. Their plates still exist in the database.

**Risk:** User thinks they've lost their registered plates and re-registers (potentially creating duplicates).

**Solution:**
- Sync checks if DB has plates that don't exist locally
- Missing plates are restored from DB to local storage
- Respects the 3-vehicle limit during restore

**Code Location:** `plate_storage_service.dart:syncWithDatabase()`

---

### 3. Network Offline During Sync
**Scenario:** App starts while device has no internet connection.

**Risk:** Sync could hang indefinitely or crash the app.

**Solution:**
- 10-second timeout on database queries
- Returns `SyncResult(wasOffline: true)` on network failure
- App continues normally with existing local data
- Sync will retry on next app launch

**Code Location:** `plate_storage_service.dart:syncWithDatabase()` - try/catch with timeout

---

### 4. Corrupted Local Storage
**Scenario:** SharedPreferences data becomes corrupted (rare, but possible after OS updates, storage issues, etc.)

**Risk:** App crashes or shows malformed data.

**Solution:**
- `validateStorageIntegrity()` checks local storage format
- If invalid, clears all local plates
- Rebuilds from database on next sync

**Code Location:** `plate_storage_service.dart:validateStorageIntegrity()`

---

### 5. User Account Changes
**Scenario:** User signs into a different account on the same device (or user ID changes for any reason).

**Risk:** New user sees previous user's plates - privacy/security breach.

**Solution:**
- Tracks `last_synced_user_id` in SharedPreferences
- If user ID differs from last sync, clears ALL local data
- Fresh sync with new account's data

**Code Location:** `plate_storage_service.dart:syncWithDatabase()` - user ID change detection

---

### 6. Orphaned Ownership Keys
**Scenario:** A plate is deleted but its ownership key remains in local storage.

**Risk:** Storage bloat, potential confusion if plate is re-registered.

**Solution:**
- After sync, `cleanupOrphanedKeys()` runs
- Compares stored keys against valid plates
- Removes any keys for non-existent plates

**Code Location:** `plate_verification_service.dart:cleanupOrphanedKeys()`

---

### 7. Database Query Timeout
**Scenario:** Database is slow or partially available.

**Risk:** App hangs waiting for response.

**Solution:**
- All DB queries have 10-second timeout
- Timeout treated same as offline - graceful skip
- No user-facing error, sync retries next launch

**Code Location:** `plate_storage_service.dart` - `.timeout(Duration(seconds: 10))`

---

### 8. Max Vehicle Limit During Restore
**Scenario:** User has 5 plates in DB but app limit is 3.

**Risk:** Could crash or violate business rules.

**Solution:**
- Restore loop checks count before each add
- Stops at limit, logs warning
- User sees as many plates as allowed

**Code Location:** `plate_storage_service.dart:syncWithDatabase()` - limit check in restore loop

---

## Sync Flow Diagram

```
App Startup
    │
    ▼
┌─────────────────────────────────┐
│  Check User ID Change           │
│  (lastSyncedUserId != current?) │
└─────────────────────────────────┘
    │ Yes → Clear all local data
    ▼
┌─────────────────────────────────┐
│  Validate Storage Integrity     │
│  (is local storage corrupted?)  │
└─────────────────────────────────┘
    │ Invalid → Clear local storage
    ▼
┌─────────────────────────────────┐
│  Fetch DB Plates                │
│  (with 10s timeout)             │
└─────────────────────────────────┘
    │ Timeout/Error → Skip sync, return offline result
    ▼
┌─────────────────────────────────┐
│  Compare Local vs DB            │
│  - Remove local-only plates     │
│  - Restore DB-only plates       │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Cleanup Orphaned Keys          │
│  (ownership keys for deleted    │
│   plates)                       │
└─────────────────────────────────┘
    │
    ▼
  Continue to main app
```

---

## SyncResult Return Values

| Scenario | synced | removedCount | restoredCount | wasOffline | message |
|----------|--------|--------------|---------------|------------|---------|
| Success, no changes | true | 0 | 0 | false | "Sync complete" |
| Removed stale plates | true | N | 0 | false | "Removed N stale plates" |
| Restored from DB | true | 0 | N | false | "Restored N plates from DB" |
| Both operations | true | X | Y | false | "Removed X, restored Y" |
| Network offline | false | 0 | 0 | true | "Offline - sync skipped" |
| Error occurred | false | 0 | 0 | false | "Sync failed: [error]" |

---

## Testing Checklist

- [ ] Delete all plates from Supabase dashboard, verify app removes local copies
- [ ] Clear app data, verify plates restore from DB
- [ ] Enable airplane mode, verify app starts without crash
- [ ] Manually corrupt SharedPreferences, verify recovery
- [ ] Log in as different user, verify old data cleared
- [ ] Delete plate, verify ownership key is cleaned up
- [ ] Test with slow network (throttled), verify timeout works
- [ ] Register 5 plates in DB, set app limit to 3, verify restore respects limit

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/core/services/plate_storage_service.dart` | Added `syncWithDatabase()`, `SyncResult` class, integrity validation |
| `lib/core/services/plate_verification_service.dart` | Added `cleanupOrphanedKeys()`, `clearAllLocalKeys()` |
| `lib/main_premium.dart` | Added sync call in `_initializeApp()`, orphan key cleanup |

---

## Future Considerations

1. **Conflict Resolution** - What if same plate exists locally AND in DB with different data? Currently DB wins.
2. **Sync Status UI** - Could show user when last sync occurred
3. **Manual Sync Button** - Allow user to force sync from settings
4. **Sync on Resume** - Currently only syncs on cold start, could sync on app resume
5. **Background Sync** - Periodic sync while app is backgrounded

---

*Report generated: November 2024*
*App Version: Premium*
