#!/usr/bin/env node
/**
 * PUSH BLASTER - Yuh Blockin' Push Notification Tester
 *
 * A quick-fire tool to send test push notifications
 *
 * Usage: node push-blaster.js
 */

const readline = require('readline');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-52358afc11.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// File to store saved tokens
const TOKENS_FILE = path.join(__dirname, '.saved-tokens.json');

// Load saved tokens
function loadTokens() {
  try {
    if (fs.existsSync(TOKENS_FILE)) {
      return JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf8'));
    }
  } catch (e) {}
  return [];
}

// Save tokens
function saveTokens(tokens) {
  fs.writeFileSync(TOKENS_FILE, JSON.stringify(tokens, null, 2));
}

// Add token to saved list
function addToken(token, name, platform = 'ios') {
  const tokens = loadTokens();
  const existing = tokens.find(t => t.token === token);
  if (!existing) {
    tokens.unshift({ token, name, platform, addedAt: new Date().toISOString() });
    if (tokens.length > 20) tokens.pop(); // Keep last 20
    saveTokens(tokens);
    return true;
  }
  return false;
}

// Remove token
function removeToken(index) {
  const tokens = loadTokens();
  if (index >= 0 && index < tokens.length) {
    tokens.splice(index, 1);
    saveTokens(tokens);
    return true;
  }
  return false;
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const ask = (q) => new Promise(resolve => rl.question(q, resolve));

// Urgency configs
const urgencyConfig = {
  '1': { level: 'low', emoji: '🙏', sound: 'low_alert_1.wav', name: 'Low' },
  '2': { level: 'normal', emoji: '🚗', sound: 'normal_alert.wav', name: 'Normal' },
  '3': { level: 'high', emoji: '🚨', sound: 'high_alert_1.wav', name: 'High' }
};

// Emoji options
const emojis = ['🚗', '🙏', '🚨', '😤', '🚙', '🅿️', '⚠️', '🔔'];

async function sendPush(token, urgency, customMessage = null, customEmoji = null, platform = 'ios') {
  const config = urgencyConfig[urgency];
  const emoji = customEmoji || config.emoji;
  const title = `${emoji} Yuh Blockin'!`;
  const body = customMessage || "Someone needs you to move your vehicle!";
  const soundFile = config.sound;
  const androidSound = soundFile.replace('.wav', '');

  // Build message with data payload (works for both platforms)
  const message = {
    token: token,
    data: {
      alert_id: 'push-blaster-test',
      type: 'alert',
      emoji: emoji,
      urgency_level: config.level,
      title: title,
      body: body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    }
  };

  // Add platform-specific config (matching alerts-fcm edge function)
  if (platform === 'android') {
    message.android = {
      priority: 'high',
      notification: {
        title: title,
        body: body,
        sound: androidSound,
        channelId: `yuh_blockin_alert_${androidSound}`,
        defaultSound: false,
        visibility: 'public'
      }
    };
  } else {
    // iOS - NO top-level notification, only apns payload for custom sound on lock screen
    message.apns = {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert'
      },
      payload: {
        aps: {
          alert: {
            title: title,
            body: body
          },
          sound: soundFile,
          badge: 1,
          'mutable-content': 1,
          'content-available': 1,
          'interruption-level': 'time-sensitive'
        }
      }
    };
  }

  console.log(`  📤 Sending ${platform.toUpperCase()} push...`);
  console.log(`     Sound: ${platform === 'android' ? androidSound : soundFile}`);

  return admin.messaging().send(message);
}

async function selectTokens() {
  const savedTokens = loadTokens();

  if (savedTokens.length === 0) {
    console.log('  No saved tokens. Add one first.');
    return [];
  }

  console.log('\n  📱 Select recipients (comma-separated, e.g., 1,3,4):');
  savedTokens.forEach((t, i) => {
    const platformIcon = (t.platform || 'ios') === 'ios' ? '🍎' : '🤖';
    console.log(`     [${i + 1}] ${platformIcon} ${t.name || 'Unnamed'} - ${t.token.substring(0, 20)}...`);
  });
  console.log(`     [A] All devices`);
  console.log('');

  const choice = await ask('  Select: ');

  if (choice.toLowerCase() === 'a') {
    return savedTokens;
  }

  const indices = choice.split(',').map(s => parseInt(s.trim()) - 1);
  return indices
    .filter(i => i >= 0 && i < savedTokens.length)
    .map(i => savedTokens[i]);
}

async function manageTokens() {
  while (true) {
    const savedTokens = loadTokens();

    console.log('\n  ═══════════════════════════════════════');
    console.log('  📱 TOKEN MANAGER');
    console.log('  ═══════════════════════════════════════');

    if (savedTokens.length > 0) {
      savedTokens.forEach((t, i) => {
        const platformIcon = (t.platform || 'ios') === 'ios' ? '🍎' : '🤖';
        console.log(`     [${i + 1}] ${platformIcon} ${t.name || 'Unnamed'} (${t.platform || 'ios'})`);
        console.log(`         ${t.token.substring(0, 40)}...`);
      });
    } else {
      console.log('     No tokens saved yet.');
    }

    console.log('');
    console.log('     [A] Add new token');
    console.log('     [D] Delete token');
    console.log('     [B] Back to main menu');
    console.log('');

    const choice = await ask('  Choice: ');

    if (choice.toLowerCase() === 'b') break;

    if (choice.toLowerCase() === 'a') {
      console.log('');
      const token = await ask('  Enter FCM token: ');
      const name = await ask('  Device name (e.g., "iPhone 15 Pro"): ');
      console.log('  Platform: [1] iOS  [2] Android');
      const platformChoice = await ask('  Select (default iOS): ');
      const platform = platformChoice === '2' ? 'android' : 'ios';
      if (token.trim()) {
        if (addToken(token.trim(), name.trim() || 'Device', platform)) {
          console.log(`  ✅ Token saved as ${platform.toUpperCase()}!`);
        } else {
          console.log('  ⚠️  Token already exists');
        }
      }
    }

    if (choice.toLowerCase() === 'd') {
      const idx = await ask('  Enter number to delete: ');
      const i = parseInt(idx) - 1;
      if (removeToken(i)) {
        console.log('  ✅ Token removed');
      } else {
        console.log('  ❌ Invalid selection');
      }
    }
  }
}

async function main() {
  console.log('\n');
  console.log('  ╔═══════════════════════════════════════════════════╗');
  console.log('  ║           ⚡ PUSH BLASTER v2.0 ⚡                  ║');
  console.log('  ║         Yuh Blockin\' Push Tester                  ║');
  console.log('  ╚═══════════════════════════════════════════════════╝');
  console.log('\n');

  // Quick add token if none exist
  let savedTokens = loadTokens();
  if (savedTokens.length === 0) {
    console.log('  No tokens saved. Let\'s add one!\n');
    const token = await ask('  Enter FCM token: ');
    const name = await ask('  Device name: ');
    console.log('  Platform: [1] iOS  [2] Android');
    const platformChoice = await ask('  Select (default iOS): ');
    const platform = platformChoice === '2' ? 'android' : 'ios';
    addToken(token.trim(), name.trim() || 'Device 1', platform);
    console.log(`  ✅ Token saved as ${platform.toUpperCase()}!\n`);
  }

  // Main loop
  while (true) {
    savedTokens = loadTokens();

    console.log('\n  ═══════════════════════════════════════');
    console.log('  MAIN MENU');
    console.log('  ═══════════════════════════════════════');
    console.log('');
    console.log('  🔥 QUICK FIRE (uses first saved token):');
    console.log('     [1] 🙏 Low alert');
    console.log('     [2] 🚗 Normal alert');
    console.log('     [3] 🚨 High alert');
    console.log('');
    console.log('  📤 ADVANCED:');
    console.log('     [M] Custom message');
    console.log('     [B] Batch send (multiple devices)');
    console.log('');
    console.log('  ⚙️  SETTINGS:');
    console.log('     [T] Manage tokens');
    console.log('     [Q] Quit');
    console.log('');

    const choice = await ask('  Select: ');

    // Quick fire options
    if (['1', '2', '3'].includes(choice)) {
      if (savedTokens.length === 0) {
        console.log('  ❌ No tokens saved. Press T to add one.');
        continue;
      }

      const token = savedTokens[0].token;
      const platform = savedTokens[0].platform || 'ios';
      const config = urgencyConfig[choice];
      const platformIcon = platform === 'ios' ? '🍎' : '🤖';
      console.log(`\n  🔥 Firing ${config.name} alert to ${platformIcon} ${savedTokens[0].name}...`);

      try {
        const result = await sendPush(token, choice, null, null, platform);
        console.log(`  ✅ SENT! ID: ${result.split('/').pop()}`);
      } catch (error) {
        console.log(`  ❌ FAILED: ${error.message}`);
      }
      continue;
    }

    // Custom message
    if (choice.toLowerCase() === 'm') {
      console.log('\n  ═══════════════════════════════════════');
      console.log('  ✉️  CUSTOM MESSAGE');
      console.log('  ═══════════════════════════════════════\n');

      // Select recipients
      const recipients = await selectTokens();
      if (recipients.length === 0) continue;

      console.log(`\n  Sending to ${recipients.length} device(s)`);

      // Select urgency
      console.log('\n  Urgency:');
      console.log('     [1] 🙏 Low');
      console.log('     [2] 🚗 Normal');
      console.log('     [3] 🚨 High');
      const urgency = await ask('  Select (1-3): ');
      if (!urgencyConfig[urgency]) {
        console.log('  ❌ Invalid');
        continue;
      }

      // Select emoji
      console.log('\n  Emoji (or press Enter for default):');
      emojis.forEach((e, i) => process.stdout.write(`  [${i + 1}]${e} `));
      console.log('');
      const emojiChoice = await ask('  Select: ');
      let emoji = urgencyConfig[urgency].emoji;
      if (emojiChoice) {
        const ei = parseInt(emojiChoice) - 1;
        if (ei >= 0 && ei < emojis.length) emoji = emojis[ei];
      }

      // Enter message
      console.log('');
      const message = await ask('  Message (or Enter for default): ');

      // Confirm
      console.log('\n  ─────────────────────────────────────');
      console.log(`  📱 To: ${recipients.map(r => r.name).join(', ')}`);
      console.log(`  ${emoji} ${urgencyConfig[urgency].name} urgency`);
      console.log(`  💬 "${message || 'Someone needs you to move your vehicle!'}"` );
      console.log('  ─────────────────────────────────────');

      const confirm = await ask('\n  Send? (Y/n): ');
      if (confirm.toLowerCase() === 'n') continue;

      // Send to all
      console.log('\n  🚀 Sending...');
      let success = 0, failed = 0;

      for (const recipient of recipients) {
        const platform = recipient.platform || 'ios';
        const platformIcon = platform === 'ios' ? '🍎' : '🤖';
        try {
          await sendPush(recipient.token, urgency, message || null, emoji, platform);
          console.log(`  ✅ ${platformIcon} ${recipient.name}`);
          success++;
        } catch (error) {
          console.log(`  ❌ ${platformIcon} ${recipient.name}: ${error.code || error.message}`);
          failed++;
        }
      }

      console.log(`\n  📊 Results: ${success} sent, ${failed} failed`);
      continue;
    }

    // Batch send
    if (choice.toLowerCase() === 'b') {
      console.log('\n  ═══════════════════════════════════════');
      console.log('  📤 BATCH SEND');
      console.log('  ═══════════════════════════════════════\n');

      const recipients = await selectTokens();
      if (recipients.length === 0) continue;

      console.log(`\n  Selected ${recipients.length} device(s)`);
      console.log('\n  Urgency:');
      console.log('     [1] 🙏 Low');
      console.log('     [2] 🚗 Normal');
      console.log('     [3] 🚨 High');
      const urgency = await ask('  Select: ');

      if (!urgencyConfig[urgency]) {
        console.log('  ❌ Invalid');
        continue;
      }

      console.log('\n  🚀 Sending to all...');
      let success = 0, failed = 0;

      for (const recipient of recipients) {
        const platform = recipient.platform || 'ios';
        const platformIcon = platform === 'ios' ? '🍎' : '🤖';
        try {
          await sendPush(recipient.token, urgency, null, null, platform);
          console.log(`  ✅ ${platformIcon} ${recipient.name}`);
          success++;
        } catch (error) {
          console.log(`  ❌ ${platformIcon} ${recipient.name}: ${error.code || error.message}`);
          failed++;
        }
      }

      console.log(`\n  📊 Results: ${success} sent, ${failed} failed`);
      continue;
    }

    // Token management
    if (choice.toLowerCase() === 't') {
      await manageTokens();
      continue;
    }

    // Quit
    if (choice.toLowerCase() === 'q') {
      console.log('\n  👋 Later!\n');
      break;
    }

    console.log('  ❌ Invalid choice');
  }

  rl.close();
  process.exit(0);
}

main().catch(console.error);
