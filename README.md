# Hello, everyone!
This mod adds new Ai to Men of War: Assault Squad 2 to make it more fun (and easier for modders) to play with bots. Also bot can spawn special point units. So enjoy this mod and let me know about bugs or your suggestions for the mod.
## Steam links
#### [Vanilla version](https://steamcommunity.com/sharedfiles/filedetails/?id=2563977509)
#### [Tanks+ version](https://steamcommunity.com/sharedfiles/filedetails/?id=2563548095)
#### [ASV version](https://steamcommunity.com/sharedfiles/filedetails/?id=2575016736)
#### [World War 3 version](https://steamcommunity.com/sharedfiles/filedetails/?id=2574393092)
#### [Great War Realism version](https://steamcommunity.com/sharedfiles/filedetails/?id=2575472270)

## Important note and enabling instruction:
To enable this mod you should simply change path in
bot revised\resource\script\multiplayer\bot.data file to units folder in your target mod. "Set" folder (subfolder of the resource folder of the target major mod, usually stored in gamelogic.pat) should not be archived! Extract it to resource folder!
Apply Bot revised after applying major mod that changes Ai (valour, warhammer, etc.)! Enable %mod_name% -> apply, enable Bot revised -> apply.

I decided to rewrite vanilla Ai to make it compatible with many major mods without making a lot of routine work with .data file in which listed all of the purchases bot can make. In Valour mod for example .data file contains literally over 9000 strings! My mod is designed to free modders from doing routine work of manually adding units and purchases for bots.

## Info for modders:
You dont need to manually add units and purchases to bot.data.lua anymore!
Mod contains 2 files: bot.data.lua which stores pathes to units (set/multiplayer/units) and bot.lua which contains unit parser and Ai logic. You can easily customise parser to disable ai from using units you dont want bot to spawn. Let me know if something is not working properly.
You are free to make compability for other mods, but give a link to main Bot Revised mod and it's submods, so people can easily find Ai for their modification, and refer to me as the creator of the Ai, so people can contact me and would leave their feedback on the main page of the mod.
