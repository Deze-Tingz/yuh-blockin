# Future Safety & Security Features

## Ownership Key System (Implemented)
- Crypto-style ownership keys (YB-XXXX-XXXX-XXXX-XXXX)
- SHA-256 hashing - server never stores plain keys
- Key stored only on user's device
- Proof of ownership via key verification

---

## Future Upgrades

### Anti-Luring Attack Prevention
- [ ] **Alert cooldown** - Max 1 alert per plate per hour from same sender
- [ ] **Night mode warnings** - Extra confirmation for alerts sent 10pm-6am
- [ ] **Suspicious pattern detection** - Flag accounts sending many alerts to different plates
- [ ] **"I don't recognize this" button** - Quick report for suspicious alerts

### Block & Report System
- [ ] **Block sender** - Block anonymous sender IDs (they can't alert you again)
- [ ] **Report alert** - Flag malicious/harassing alerts for review
- [ ] **Repeat offender tracking** - Auto-restrict accounts with multiple reports

### Privacy Enhancements
- [ ] **Anonymous alerts** - Sender identity never revealed (already implemented)
- [ ] **No location data** - Alerts contain no location info (already implemented)
- [ ] **Encrypted local storage** - Encrypt ownership keys on device
- [ ] **Biometric protection** - Require fingerprint/face to view keys

### Key Management
- [ ] **Key backup to cloud** - Optional encrypted backup
- [ ] **Key recovery via email** - If user loses device
- [ ] **Multi-device sync** - Share keys across devices securely
- [ ] **Key rotation reminders** - Periodic prompts to rotate keys

### Multi-Vehicle Support
- [ ] **Fleet owner mode** - Register and manage multiple plates under one account
- [ ] **Vehicle nicknames** - Label plates (e.g., "Work Truck", "Wife's Car", "Family Van")
- [ ] **Quick vehicle switcher** - Easy toggle between vehicles when sending alerts
- [ ] **Per-vehicle alert history** - View alerts grouped by vehicle
- [ ] **Family sharing** - Share vehicle access with family members (each gets their own key)
- [ ] **Business accounts** - Fleet management for businesses with many vehicles

### Transparency Features
- [ ] **Alert history** - See all alerts received with timestamps
- [ ] **"How it works" explainer** - In-app guide to the security model
- [ ] **Data export** - Let users export all their data
- [ ] **Delete account** - Full data deletion option

---

## Implementation Priority
1. Block sender (high impact, moderate effort)
2. Alert cooldown (high impact, low effort)
3. Report system (high impact, moderate effort)
4. Night mode warnings (medium impact, low effort)
5. Multi-vehicle support (high impact, moderate effort) - Many users own multiple vehicles
6. Vehicle nicknames (medium impact, low effort) - Quick win for UX
