// Electron main process: opens the RPG Maker MZ game that lives one folder up
// in a native Linux window. The game was shipped for NW.js, so preload.js
// provides the handful of NW.js APIs it calls.

const { app, BrowserWindow, Menu, ipcMain, shell } = require("electron");
const path = require("path");

const GAME_DIR = process.env.STRANDED_GAME_DIR
    ? path.resolve(process.env.STRANDED_GAME_DIR)
    : path.resolve(__dirname, "..");
const GAME_WIDTH = 1280;
const GAME_HEIGHT = 720;

// Same flag the original NW.js manifest passed, keeps colours identical.
app.commandLine.appendSwitch("force-color-profile", "srgb");
// Game.sh captures stderr in launcher.log, including failures that happen
// before a window is created.
app.commandLine.appendSwitch("enable-logging", "stderr");
// Use Wayland natively when available, X11 otherwise. Avoids XWayland blur
// on fractional scaling.
app.commandLine.appendSwitch("ozone-platform-hint", "auto");
app.commandLine.appendSwitch("enable-features", "WaylandWindowDecorations");

// Only let the game hand off links it is meant to open (store page, Steam).
const EXTERNAL_PROTOCOLS = new Set(["http:", "https:", "steam:"]);

function openExternal(url) {
    try {
        if (EXTERNAL_PROTOCOLS.has(new URL(url).protocol)) {
            shell.openExternal(url);
        }
    } catch (e) {
        console.error("Refusing to open", url, e);
    }
}

function createWindow() {
    const win = new BrowserWindow({
        width: GAME_WIDTH,
        height: GAME_HEIGHT,
        useContentSize: true,
        minWidth: GAME_WIDTH / 4,
        minHeight: GAME_HEIGHT / 4,
        center: true,
        backgroundColor: "#000000",
        title: "Stranded with You",
        icon: path.join(GAME_DIR, "icon", "icon.png"),
        show: false,
        webPreferences: {
            preload: path.join(__dirname, "preload.js"),
            // RPG Maker MZ detects "desktop mode" (file saves in save/) by
            // the presence of require/process in the page, like NW.js.
            nodeIntegration: true,
            contextIsolation: false,
            sandbox: false,
            // Title music starts without needing a click first.
            autoplayPolicy: "no-user-gesture-required",
            // Keep music and timers running when the window loses focus.
            backgroundThrottling: false,
            spellcheck: false,
        },
    });

    Menu.setApplicationMenu(null);
    win.setAspectRatio(GAME_WIDTH / GAME_HEIGHT);
    win.once("ready-to-show", () => win.show());

    // The game never needs to navigate away or open popups. Send links to
    // the desktop browser instead.
    win.webContents.setWindowOpenHandler(({ url }) => {
        openExternal(url);
        return { action: "deny" };
    });
    win.webContents.on("will-navigate", (event, url) => {
        if (!url.startsWith("file://")) {
            event.preventDefault();
            openExternal(url);
        }
    });

    // F11 / Alt+Enter toggle fullscreen at the window level, which behaves
    // better on Wayland compositors than the page-level fullscreen F4 uses.
    win.webContents.on("before-input-event", (event, input) => {
        if (input.type !== "keyDown") return;
        const altEnter = input.alt && input.key === "Enter";
        if (input.key === "F11" || altEnter) {
            event.preventDefault();
            win.setFullScreen(!win.isFullScreen());
        }
    });

    win.loadFile(path.join(GAME_DIR, "index.html"));
    return win;
}

ipcMain.on("openExternal", (_event, url) => openExternal(url));
ipcMain.on("quit", () => app.quit());
ipcMain.on("toggleDevTools", (event) => event.sender.toggleDevTools());

app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());
app.on("render-process-gone", (_event, _webContents, details) => {
    console.error("Renderer process exited", details);
});
app.on("child-process-gone", (_event, details) => {
    console.error("Electron child process exited", details);
});

process.on("uncaughtException", error => {
    console.error("Uncaught Electron main-process error", error);
});
process.on("unhandledRejection", error => {
    console.error("Unhandled Electron main-process rejection", error);
});
