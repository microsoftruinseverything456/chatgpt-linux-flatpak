const { app, BrowserWindow, Menu, shell } = require('electron');
const path = require('path');

let win;

const ALLOWED_HOSTS = [
  'chatgpt.com',
  'openai.com',
  'sora.openai.com',
  'auth.openai.com',
  'platform.openai.com',
  'help.openai.com',
  'accounts.google.com',
  'appleid.apple.com',
  'login.microsoftonline.com',
  'github.com',
];

function isAllowed(urlString) {
  try {
    const u = new URL(urlString);
    const host = u.hostname.toLowerCase();
    if (u.protocol !== 'https:') return false;
    return ALLOWED_HOSTS.some(allowed => host === allowed || host.endsWith(`.${allowed}`));
  } catch {
    return false;
  }
}

function isHttpUrl(u) {
  return u.protocol === 'http:' || u.protocol === 'https:';
}

function shouldOpenExternally(targetUrl) {
  try {
    const u = new URL(targetUrl);

    // Don't touch non-web schemes (needed for uploads, blobs, etc.)
    if (!isHttpUrl(u)) return false;

    // If it's not an allowed domain, open in browser
    return !isAllowed(targetUrl);
  } catch {
    return false;
  }
}

// ---- Single instance lock (must be near the top) ----
const gotLock = app.requestSingleInstanceLock();

if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.show();
      win.focus();
    }
  });

  function createWindow() {
    win = new BrowserWindow({
      width: 1200,
      height: 800,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
      },
      icon: path.join(__dirname, 'assets/icons/build/icons/64x64.png'),
    });

    // Keep keyboard shortcuts like Ctrl+W even with a hidden menu bar
    const menu = Menu.buildFromTemplate([
      {
        label: 'File',
        submenu: [
          { role: 'close', accelerator: 'Ctrl+W' },
          { role: 'quit', accelerator: 'Ctrl+Q' },
        ],
      },
      {
        label: 'View',
        submenu: [
          { role: 'reload', accelerator: 'Ctrl+R' },
          { role: 'toggledevtools', accelerator: 'Ctrl+Shift+I' },
          { type: 'separator' },
          { role: 'resetzoom' },
          { role: 'zoomin' },
          { role: 'zoomout' },
          { type: 'separator' },
          { role: 'togglefullscreen', accelerator: 'F11' },
        ],
      },
    ]);

    Menu.setApplicationMenu(menu);
    win.setMenuBarVisibility(false); // menu hidden, shortcuts still work

    win.webContents.setWindowOpenHandler(({ url }) => {
      if (shouldOpenExternally(url)) {
        shell.openExternal(url);
        return { action: 'deny' };
      }
      return { action: 'allow' };
    });

    win.webContents.on('will-navigate', (event, targetUrl) => {
      if (shouldOpenExternally(targetUrl)) {
        event.preventDefault();
        shell.openExternal(targetUrl);
      }
    });

    win.webContents.on('will-redirect', (event, targetUrl) => {
      if (shouldOpenExternally(targetUrl)) {
        event.preventDefault();
        shell.openExternal(targetUrl);
      }
    });

    win.loadURL('https://chatgpt.com/');

    win.on('closed', () => {
      win = null;
    });
  }

  app.whenReady().then(createWindow);

  app.on('window-all-closed', () => {
    app.quit();
  });
}
