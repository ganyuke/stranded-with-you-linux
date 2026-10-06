# Stranded with You on Linux

| Before | After |
| :---: | :---: |
| <img width="100%" alt="before screenshot where erroneous bar is present." src="https://github.com/user-attachments/assets/b93e8ceb-1ab4-4e6a-b2a7-7357838df849" /> | <img width="100%" alt="after screenshot where erroneous bar is missing." src="https://github.com/user-attachments/assets/0c070842-b25e-4102-83ae-114f9412052c" /> |

There was a certain visual novel on Steam titled [Stranded with You](https://store.steampowered.com/app/4260270/Stranded_with_You/) that just so happened to cross my Steam Discovery Queue and the tags combined with the childhood friend premise and the cute, shark-toothed female main character design piqued my interest. And no, I have not played the patch despite my 10 hour playtime.

There was a major problem though: it is a Windows-based RPG Maker game with just an `.exe` and for some reason, RPG Maker on my NVIDIA Bazzite install pushes down the entire window, leaving a blank bar at the top visually. However, inputs are still in their [original positions](#this-is-annoying-to-play-around), so every button is slightly out of place vertically. Which is annoying! Nothing scales right!

But I took a look at the files and realized something incredible: RPG Maker games are just glorified JavaScript. You know what also runs JavaScript and, in particular is notorious for being a RAM eater? That's right! [Electron](https://www.electronjs.org/)! And if RPG Maker games were, in effect, just glorified browsers and they needed a JavaScript engine, does that mean I can replace NW.js with Electron?

The answer: yes!! >:)

So I (and now you) can play Stranded with You natively on Linux instead of through Proton, replacing NW.js with Electron for funsies and also just so happening to fix RPG Maker's weird scaling issue along the way.

This is a drop-in modification for Stranded with You, providing an alternative launcher within the game files. It does not include or alter any of the game's files. You must own the game first before you can use this mod.

Steam achivements are fully functional with this modification, provided you launch the game through Steam and not directly.

## Installation and setup

Download the latest release (`tar.gz`) from the GitHub Releases section in this repository. Extract the contents of this `tar.gz` (`stranded-with-you-linux`) to Stranded with You game's Steam folder. To find the game folder, you can right-click Stranded with You in your Steam library, click Manage, then Browse local files.

To force Steam to run the newly-installed Linux endpoint, open the game's properties and set its advanced launch options to:

```
"./stranded-with-you-linux/Game.sh" # %command%
```

This will let you track your game time and Steam achivements.

If you want to run Stranded with You separately, you can simply run the `Game.sh` file directly. Steam is unable to track your playtime or achivements with this method.

This modification does not touch anything except the JavaScript engine and entrypoint. Saves made through the original Windows port should work with this Linux modification and vice versa.

## Quirks

You can fullscreen the game using F11 or Alt+Enter, though it's a 1280x720 game by design, so the game textures are not really going to look all that good for most monitors (1920x1080).

You can resize the game as you want and it will maintain the 16:9 aspect ratio, though it's a little wonky and produces a useless scrollbar below 720 vertical pixels.

The native Steam overlay is manually disabled because, for some reason, the Steam overlay prevents Electron from starting.

## Troubleshooting

The launcher automatically creates the text file `stranded-with-you-linux/launcher.log` on start. If you are having trouble with Steam launching the game, you might find the answer there.

## Uninstall

Delete the `stranded-with-you-linux` folder from Stranded with You's Steam game folder.

## This is annoying to play around

https://github.com/user-attachments/assets/feff763f-32e8-43a0-8d98-94e68adb1bbc
