// Runs in the game page before js/main.js. The game and its plugins were
// written for NW.js, so this recreates the small part of NW.js they use
// (window.nw, require("nw.gui"), process.mainModule) on top of Electron.

const { ipcRenderer } = require("electron");
const Module = require("module");
const path = require("path");

const GAME_DIR = process.env.STRANDED_GAME_DIR
    ? path.resolve(process.env.STRANDED_GAME_DIR)
    : path.resolve(__dirname, "..");

// RPG Maker MZ and several plugins locate the save/ folder through
// process.mainModule.filename, which is the game's index.html under NW.js.
Object.defineProperty(process, "mainModule", {
    value: { filename: path.join(GAME_DIR, "index.html") },
    configurable: true,
    writable: true,
});

const openExternal = (url) => ipcRenderer.send("openExternal", String(url));

const nwWindow = {
    on() {},
    once() {},
    removeAllListeners() {},
    showDevTools: () => ipcRenderer.send("toggleDevTools"),
    closeDevTools: () => ipcRenderer.send("toggleDevTools"),
    close: () => ipcRenderer.send("quit"),
    focus: () => window.focus(),
};

const nw = {
    App: {
        // Launch arguments like "test" put RPG Maker into playtest mode.
        // Players never pass them, so keep this empty.
        argv: [],
        quit: () => ipcRenderer.send("quit"),
    },
    Window: { get: () => nwWindow },
    Shell: { openExternal },
    Clipboard: {
        get: () => ({
            set: (text) => navigator.clipboard.writeText(String(text)),
            get: () => "",
        }),
    },
};
window.nw = nw;

window.chrome = window.chrome || {};
window.chrome.runtime = window.chrome.runtime || {};
window.chrome.runtime.reload = () => location.reload();

// The shipped game uses Greenworks, but only includes its Windows binary.
// Adapt the small Greenworks surface used by Shiro_SteamworksAPI to the
// maintained, Linux-compatible steamworks.js module.
let steamClient = null;

function steamAppIdFromEnvironment() {
    const value = process.env.SteamAppId || process.env.SteamGameId;
    return /^\d+$/.test(value || "") ? Number(value) : undefined;
}

const steamAdapter = {
    init() {
        if (steamClient) return true;

        try {
            const steamworks = require("steamworks.js");
            // Steam supplies SteamAppId when Game.sh is launched from the
            // game's library page. With no environment value, steamworks.js
            // falls back to steam_appid.txt for local development.
            steamClient = steamworks.init(steamAppIdFromEnvironment());
            console.info(
                `Steamworks initialized for App ID ${steamClient.utils.getAppId()}`
            );
            return true;
        } catch (error) {
            console.error(
                "Steamworks initialization failed. Launch Game.sh from the game's Steam library page.",
                error
            );
            steamClient = null;
            return false;
        }
    },

    initAPI() {
        return this.init();
    },

    isSteamRunning() {
        return steamClient !== null;
    },

    getAppId() {
        return steamClient
            ? steamClient.utils.getAppId()
            : (steamAppIdFromEnvironment() || 0);
    },

    activateAchievement(achievementId, success, failure) {
        try {
            if (!steamClient) throw new Error("Steamworks is not initialized");

            if (steamClient.achievement.activate(String(achievementId))) {
                if (success) success();
            } else if (failure) {
                failure(new Error(`Steam rejected achievement ${achievementId}`));
            }
        } catch (error) {
            console.error(`Could not unlock Steam achievement ${achievementId}`, error);
            if (failure) failure(error);
        }
    },
};

const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
    if (request === "nw.gui") {
        return nw;
    }
    if (/(^|[\\/])greenworks(\.js)?$/.test(request)) {
        return steamAdapter;
    }
    return originalLoad.call(this, request, parent, isMain);
};
