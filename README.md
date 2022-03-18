# Hello, everyone!
This mod adds new Ai to Men of War: Assault Squad 2 to make it more fun (and easier for modders) to play with bots. Also bot can spawn special point units. So enjoy this mod and let me know about bugs or your suggestions for the mod.
## Steam links
#### [Standalone version](https://steamcommunity.com/sharedfiles/filedetails/?id=2780540106)
#### [Vanilla version](https://steamcommunity.com/sharedfiles/filedetails/?id=2780547085)
#### [Great War Realism version](https://steamcommunity.com/sharedfiles/filedetails/?id=2575472270)
#### [Tanks+ version](https://steamcommunity.com/sharedfiles/filedetails/?id=2780547540)
### Outdated V1 versions (not yet updated to V2)
#### [World War 3](https://steamcommunity.com/sharedfiles/filedetails/?id=2574393092)

## Important note and how to enable?
To enable this mod you should simply change path in
bot revised\resource\script\multiplayer\bot.data file to units folder in your target mod. "Set" folder (subfolder of the resource folder of the target major mod, usually stored in gamelogic.pat) should not be archived! Extract it to resource folder!
Apply Bot Revised after applying major mod that changes Ai (valour, tanks+, etc.)! Enable %mod_name% -> apply, enable Bot Revised -> apply.

## Mod features
* Atomatical unit parsing[/b]. Thats it, you don't need to manually add units to AI's purchase list. But you can customise which unit (or group of units) can be used by AI and which can not by including key words in parser's black list.
* Dynamical system of AI's unit purchasing[/b] based on "factors", allowing the bot to adjust it's choice to the current situation on the battlefield. Like "if enemy has 2 or more units of class tank, i should buy a tank destroyer!" or "If my team have no heavy tanks and enemy team have 4 or more tanks and my team are loosing i should buy heavy tank!" and more, there are a lot of different situations in game which AI can handle if AI is set to do so. See bot.lua for details.
* Dynamical system of flag handling[/b]. Every flag on the map has status: "clear", "attacked", "defended" (and more), occupant: team, enemy, neutral, attached units and their count. AI calculates priority of every flag and decides whether to lauch a massive attack on enemy flag, or defend team flag. Flag handling system and unit handling system have great potential altogether, which currently is not fully used (e.g. AI potentialy can send bazookers to kill enemy artillery on flag behind enemy lines). Using this potential is your task, with BotInfoApi tools it will be easy, i don't have enough imagination and time ;)
* Unit class system. You can create as many unit classes as you wish, like "Defense units", "Ultimate units", "Scout units", "Saboteur units" and others.
* BotInfoApi. This API is created for receiving and sending information about situation on battlefield through file-messaging between bots. Each bot "knows" names, costs, locations and other information about enemy and their team units. Don't be afraid of appering command prompt windows on start of the match - there are no way to delete files or scan directory in pure LUA, this is possible only when using a command prompt.
* Handling of unit timers.
* Handling of special AI scripts and units. This AI is used in ASV WH40K and utilises all of it's AI scripts features.
* Ability to purchase special point units.
* Compability with major modifications, like ASV, Cold War, and others.
* Good performance optimisation and commented code.
* Other unsaid but important features for modders which you can see in code.

### Credits and contribution history
#### Why reupload?
Mod had been improved significantly: 95% of code had been rewritten, new complete API system (BotInfoApi) added, bugs fixed, performance improved. There was a lot of continious work and core ai changes, that is why i decided to upload new version separately. Old version will be removed from workshop in a short period of time.
#### Major differencies with Bot Revised V1
Whole new API system - BotInfoApi.
New dynamic unit handling system.
New dynamic flag handling system.
Bug fixes.
Overall improvements.
#### Can i adopt your AI for my (or someone else's) mod?
Yes, of course. That is why i made this AI mod - to make it easier for people to find good AI for their mods. You can contact me if you need help with making versions for other mods. See info for modders below.

## Info for modders:
You dont need to manually add units and purchases to bot.data.lua anymore!
Mod contains 2 files: bot.data.lua which stores pathes to units (set/multiplayer/units) and bot.lua which contains unit parser and AI logic. You can easily customise all aspects of the AI and adjust parser to disable AI from using units you don't want bot to spawn. Let me know if something is not working properly.
You are free to make compability with other mods, but give a link to main Bot Revised mod and it's submods, so people can easily find Ai for their modification, and refer to me as the creator of the AI, so people can contact me and would leave their feedback on the main page of the mod.

