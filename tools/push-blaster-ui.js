#!/usr/bin/env node
/**
 * PUSH BLASTER UI - Web-based Push Notification Tester
 *
 * Run: node push-blaster-ui.js
 * Opens in browser at http://localhost:3333
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-52358afc11.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const TOKENS_FILE = path.join(__dirname, '.saved-tokens.json');
const PORT = 3333;

// Token management
function loadTokens() {
  try {
    if (fs.existsSync(TOKENS_FILE)) {
      return JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf8'));
    }
  } catch (e) {}
  return [];
}

function saveTokens(tokens) {
  fs.writeFileSync(TOKENS_FILE, JSON.stringify(tokens, null, 2));
}

// Send push notification
async function sendPush(token, urgency, customMessage, customEmoji, platform = 'ios') {
  const configs = {
    low: { emoji: '🙏', sound: 'low_alert_1.wav' },
    normal: { emoji: '🚗', sound: 'normal_alert.wav' },
    high: { emoji: '🚨', sound: 'high_alert_1.wav' }
  };

  const config = configs[urgency] || configs.normal;
  const emoji = customEmoji || config.emoji;
  const title = `${emoji} Yuh Blockin'!`;
  const body = customMessage || "Someone needs you to move your vehicle!";
  const soundFile = config.sound;
  const androidSound = soundFile.replace('.wav', '');

  // Build message with data payload
  const message = {
    token,
    data: {
      alert_id: 'push-blaster-test',
      emoji, urgency_level: urgency,
      title, body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    }
  };

  // Add platform-specific config (matching alerts-fcm edge function)
  if (platform === 'android') {
    message.android = {
      priority: 'high',
      notification: {
        title, body,
        sound: androidSound,
        channelId: `yuh_blockin_alert_${androidSound}`,
        defaultSound: false,
        visibility: 'public'
      }
    };
  } else {
    // iOS - NO top-level notification, only apns payload for custom sound on lock screen
    message.apns = {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
      payload: {
        aps: {
          alert: { title, body },
          sound: soundFile,
          badge: 1,
          'mutable-content': 1,
          'content-available': 1,
          'interruption-level': 'time-sensitive'
        }
      }
    };
  }

  console.log(`Sending ${platform.toUpperCase()} push - Sound: ${platform === 'android' ? androidSound : soundFile}`);
  return admin.messaging().send(message);
}

// HTML UI
const html = `<!DOCTYPE html>
<html>
<head>
  <title>Push Blaster</title>
  <meta charset="UTF-8">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      min-height: 100vh;
      color: #fff;
      padding: 40px 20px;
    }
    .container {
      max-width: 500px;
      margin: 0 auto;
    }
    h1 {
      text-align: center;
      font-size: 28px;
      margin-bottom: 8px;
      background: linear-gradient(90deg, #f39c12, #e74c3c);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle {
      text-align: center;
      color: #888;
      margin-bottom: 30px;
      font-size: 14px;
    }
    .card {
      background: rgba(255,255,255,0.05);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 20px;
      border: 1px solid rgba(255,255,255,0.1);
    }
    .card-title {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #888;
      margin-bottom: 16px;
    }
    .device-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-bottom: 12px;
    }
    .device {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px;
      background: rgba(255,255,255,0.03);
      border-radius: 10px;
      cursor: pointer;
      transition: all 0.2s;
      border: 2px solid transparent;
    }
    .device:hover { background: rgba(255,255,255,0.08); }
    .device.selected { border-color: #f39c12; background: rgba(243,156,18,0.1); }
    .device-icon { font-size: 24px; }
    .device-info { flex: 1; }
    .device-name { font-weight: 600; font-size: 14px; }
    .device-token { font-size: 11px; color: #666; font-family: monospace; }
    .device-check { width: 20px; height: 20px; border-radius: 50%; border: 2px solid #444; }
    .device.selected .device-check { background: #f39c12; border-color: #f39c12; }

    .urgency-btns {
      display: flex;
      gap: 10px;
    }
    .urgency-btn {
      flex: 1;
      padding: 16px 12px;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      font-size: 14px;
      font-weight: 600;
      transition: all 0.2s;
      background: rgba(255,255,255,0.05);
      color: #fff;
      border: 2px solid transparent;
    }
    .urgency-btn:hover { transform: translateY(-2px); }
    .urgency-btn.selected { border-color: currentColor; }
    .urgency-btn.low { color: #3498db; }
    .urgency-btn.low.selected { background: rgba(52,152,219,0.2); }
    .urgency-btn.normal { color: #f39c12; }
    .urgency-btn.normal.selected { background: rgba(243,156,18,0.2); }
    .urgency-btn.high { color: #e74c3c; }
    .urgency-btn.high.selected { background: rgba(231,76,60,0.2); }
    .urgency-btn .emoji { font-size: 24px; display: block; margin-bottom: 4px; }

    .emoji-picker {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
    .emoji-opt {
      width: 44px;
      height: 44px;
      border-radius: 10px;
      border: 2px solid transparent;
      background: rgba(255,255,255,0.05);
      font-size: 22px;
      cursor: pointer;
      transition: all 0.2s;
    }
    .emoji-opt:hover { background: rgba(255,255,255,0.1); }
    .emoji-opt.selected { border-color: #f39c12; background: rgba(243,156,18,0.2); }

    input, textarea {
      width: 100%;
      padding: 14px;
      border-radius: 10px;
      border: 1px solid rgba(255,255,255,0.1);
      background: rgba(0,0,0,0.3);
      color: #fff;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
    }
    input:focus, textarea:focus { border-color: #f39c12; }
    textarea { resize: none; height: 80px; }
    input::placeholder, textarea::placeholder { color: #555; }

    .fire-btn {
      width: 100%;
      padding: 18px;
      border: none;
      border-radius: 14px;
      background: linear-gradient(135deg, #f39c12, #e74c3c);
      color: #fff;
      font-size: 18px;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.2s;
      text-transform: uppercase;
      letter-spacing: 2px;
    }
    .fire-btn:hover { transform: translateY(-2px); box-shadow: 0 10px 30px rgba(243,156,18,0.3); }
    .fire-btn:active { transform: translateY(0); }
    .fire-btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

    .result {
      text-align: center;
      padding: 16px;
      border-radius: 10px;
      margin-top: 16px;
      font-weight: 600;
    }
    .result.success { background: rgba(46,204,113,0.2); color: #2ecc71; }
    .result.error { background: rgba(231,76,60,0.2); color: #e74c3c; }

    .add-device {
      display: flex;
      gap: 8px;
      margin-top: 12px;
    }
    .add-device input { flex: 1; }
    .add-btn {
      padding: 0 20px;
      background: #f39c12;
      border: none;
      border-radius: 10px;
      color: #000;
      font-weight: 600;
      cursor: pointer;
    }
    .delete-btn {
      background: rgba(231,76,60,0.2);
      border: none;
      color: #e74c3c;
      width: 30px;
      height: 30px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 16px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>⚡ PUSH BLASTER</h1>
    <p class="subtitle">Yuh Blockin' Push Notification Tester</p>

    <div class="card">
      <div class="card-title">📱 Devices</div>
      <div class="device-list" id="deviceList"></div>
      <div class="add-device">
        <input type="text" id="newToken" placeholder="FCM Token">
        <input type="text" id="newName" placeholder="Name" style="max-width:120px">
        <button class="add-btn" onclick="addDevice()">+</button>
      </div>
    </div>

    <div class="card">
      <div class="card-title">🔔 Urgency</div>
      <div class="urgency-btns">
        <button class="urgency-btn low" onclick="setUrgency('low')">
          <span class="emoji">🙏</span>Low
        </button>
        <button class="urgency-btn normal selected" onclick="setUrgency('normal')">
          <span class="emoji">🚗</span>Normal
        </button>
        <button class="urgency-btn high" onclick="setUrgency('high')">
          <span class="emoji">🚨</span>High
        </button>
      </div>
    </div>

    <div class="card">
      <div class="card-title">😀 Emoji (optional)</div>
      <div class="emoji-picker">
        <button class="emoji-opt" onclick="setEmoji('')">🚫</button>
        <button class="emoji-opt" onclick="setEmoji('🚗')">🚗</button>
        <button class="emoji-opt" onclick="setEmoji('🙏')">🙏</button>
        <button class="emoji-opt" onclick="setEmoji('🚨')">🚨</button>
        <button class="emoji-opt" onclick="setEmoji('😤')">😤</button>
        <button class="emoji-opt" onclick="setEmoji('🚙')">🚙</button>
        <button class="emoji-opt" onclick="setEmoji('🅿️')">🅿️</button>
        <button class="emoji-opt" onclick="setEmoji('⚠️')">⚠️</button>
      </div>
    </div>

    <div class="card">
      <div class="card-title">💬 Custom Message (optional)</div>
      <textarea id="message" placeholder="Someone needs you to move your vehicle!"></textarea>
    </div>

    <button class="fire-btn" id="fireBtn" onclick="fire()">🔥 FIRE!</button>
    <div id="result"></div>
  </div>

  <script>
    let devices = [];
    let selectedDevices = new Set();
    let urgency = 'normal';
    let emoji = '';

    async function loadDevices() {
      const res = await fetch('/api/tokens');
      devices = await res.json();
      renderDevices();
    }

    function renderDevices() {
      const list = document.getElementById('deviceList');
      list.innerHTML = devices.map((d, i) => \`
        <div class="device \${selectedDevices.has(i) ? 'selected' : ''}" onclick="toggleDevice(\${i})">
          <span class="device-icon">\${(d.platform || 'ios') === 'ios' ? '🍎' : '🤖'}</span>
          <div class="device-info">
            <div class="device-name">\${d.name} <span style="color:#666;font-size:11px">(\${d.platform || 'ios'})</span></div>
            <div class="device-token">\${d.token.substring(0, 30)}...</div>
          </div>
          <button class="delete-btn" onclick="deleteDevice(\${i}, event)">×</button>
          <div class="device-check"></div>
        </div>
      \`).join('');
    }

    function toggleDevice(i) {
      if (selectedDevices.has(i)) selectedDevices.delete(i);
      else selectedDevices.add(i);
      renderDevices();
    }

    async function addDevice() {
      const token = document.getElementById('newToken').value.trim();
      const name = document.getElementById('newName').value.trim() || 'Device';
      if (!token) return;

      await fetch('/api/tokens', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, name })
      });

      document.getElementById('newToken').value = '';
      document.getElementById('newName').value = '';
      loadDevices();
    }

    async function deleteDevice(i, e) {
      e.stopPropagation();
      await fetch('/api/tokens/' + i, { method: 'DELETE' });
      selectedDevices.delete(i);
      loadDevices();
    }

    function setUrgency(u) {
      urgency = u;
      document.querySelectorAll('.urgency-btn').forEach(b => b.classList.remove('selected'));
      document.querySelector('.urgency-btn.' + u).classList.add('selected');
    }

    function setEmoji(e) {
      emoji = e;
      document.querySelectorAll('.emoji-opt').forEach(b => b.classList.remove('selected'));
      if (e) event.target.classList.add('selected');
    }

    async function fire() {
      const selected = Array.from(selectedDevices);
      if (selected.length === 0) {
        showResult('Select at least one device', false);
        return;
      }

      const btn = document.getElementById('fireBtn');
      btn.disabled = true;
      btn.textContent = '🚀 SENDING...';

      const message = document.getElementById('message').value.trim();

      try {
        const res = await fetch('/api/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            deviceIndices: selected,
            urgency, emoji, message
          })
        });
        const data = await res.json();

        if (data.success > 0) {
          showResult(\`✅ Sent to \${data.success} device(s)\` + (data.failed > 0 ? \` (\${data.failed} failed)\` : ''), true);
        } else {
          showResult('❌ All sends failed', false);
        }
      } catch (e) {
        showResult('❌ Error: ' + e.message, false);
      }

      btn.disabled = false;
      btn.textContent = '🔥 FIRE!';
    }

    function showResult(msg, success) {
      const el = document.getElementById('result');
      el.textContent = msg;
      el.className = 'result ' + (success ? 'success' : 'error');
      setTimeout(() => el.textContent = '', 3000);
    }

    loadDevices();
  </script>
</body>
</html>`;

// HTTP Server
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  // Serve HTML
  if (url.pathname === '/' || url.pathname === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
    return;
  }

  // API: Get tokens
  if (url.pathname === '/api/tokens' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(loadTokens()));
    return;
  }

  // API: Add token
  if (url.pathname === '/api/tokens' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      const { token, name } = JSON.parse(body);
      const tokens = loadTokens();
      if (!tokens.find(t => t.token === token)) {
        tokens.unshift({ token, name, addedAt: new Date().toISOString() });
        saveTokens(tokens);
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    });
    return;
  }

  // API: Delete token
  if (url.pathname.startsWith('/api/tokens/') && req.method === 'DELETE') {
    const idx = parseInt(url.pathname.split('/').pop());
    const tokens = loadTokens();
    if (idx >= 0 && idx < tokens.length) {
      tokens.splice(idx, 1);
      saveTokens(tokens);
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  // API: Send push
  if (url.pathname === '/api/send' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      const { deviceIndices, urgency, emoji, message } = JSON.parse(body);
      const tokens = loadTokens();

      let success = 0, failed = 0;

      for (const idx of deviceIndices) {
        if (idx >= 0 && idx < tokens.length) {
          try {
            await sendPush(tokens[idx].token, urgency, message || null, emoji || null);
            success++;
          } catch (e) {
            console.error(`Failed to send to ${tokens[idx].name}:`, e.message);
            failed++;
          }
        }
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success, failed }));
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log('\n  ╔═══════════════════════════════════════════════════╗');
  console.log('  ║           ⚡ PUSH BLASTER UI ⚡                    ║');
  console.log('  ╚═══════════════════════════════════════════════════╝\n');
  console.log(`  🌐 Open in browser: http://localhost:${PORT}\n`);

  // Try to open browser automatically
  const { exec } = require('child_process');
  exec(`start http://localhost:${PORT}`);
});
