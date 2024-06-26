# LuaLS setup for Deadly Boss Mods

A LuaLS plugin for DBM development, features:

* Dynamic and automatically derived definitions for DBM mods
* Custom diagnostics that find common mistakes in event handlers
* A few extra definitions beyond what [vscode-wow-api](https://github.com/Ketho/vscode-wow-api), mostly for Classic

## Features

**Event registration check**

Checks if events for the handlers you define are registered, including checking for spell IDs referenced in the handler.

![](./Screenshots/SpellID-Missing.png)

**Sync handler check**

Finds mismatches between sync messages sent and received.

![](./Screenshots/Sync-Checker.png)

**Auto-complete for events**

Includes support for combat log sub-events and DBM-specific events like `_UNFILTERED` unit events.

![](./Screenshots/Event-Enum.png)

**Finds typos and other mistakes that are hard to spot**

![](./Screenshots/Event-Handler-Params.png)

**Can't remember all the NewTimer and NewAnnounce things? We got autocomplete for all of these!**

![](./Screenshots/Timers.png)

**NewTimer takes 17 parameters, do you know which is which at a glance?**

![](./Screenshots/Parameters.png)
(`Cmd+Shift+Space` in VS Code)

## Setup for development

1. Install [Visual Studio Code](https://code.visualstudio.com/)
2. Install the [lua-language-server extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) for VS Code
3. Install the [WoW API extension](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api) for VS Code
4. Clone this repo: `git clone git@github.com:DeadlyBossMods/LuaLS-Config`
5. Open VS Code's settings.json (`Cmd+Shift+P` -> "Open User Settings (JSON)")
6. Enable the DBM plugin for LuaLS to settings.json
	1. Add this line: `"Lua.runtime.plugin": "<path to where you cloned LuaLS-Config>/Plugin/Plugin.lua",`
7. Add extra definitions for DBM to settings.json
	1. Find the `Lua.workspace.library` entry, it should already exist and have entries from the WoW API extension
	2. Add this line to the library array: `<path to where you cloned LuaLS-Config>/Definitions`
	3. Add this line to the library array: `<path to where you cloned the main DeadlyBossMods repo>/DBM-Core`
	4. Add this line to the library array: `<path to where you cloned the main DeadlyBossMods repo>/DBM-StatusBarTimers`
	5. Add this line to the library array: `<path to where you cloned the main DeadlyBossMods repo>/DBM-Test`

Your settings.json should look like this afterwards:

```
	"Lua.workspace.library": [
		"C:/Users/You/wow-addons/DeadlyBossMods/DBM-Core",
		"C:/Users/You/wow-addons/DeadlyBossMods/DBM-StatusBarTimers",
		"C:/Users/You/wow-addons/DeadlyBossMods/DBM-Test",
		"C:/Users/You/wow-addons/LuaLS-Config/Definitions",
		"c:\\Users\\You\\.vscode\\extensions\\ketho.wow-api-0.13.x\\EmmyLua\\API",
		"c:\\Users\\You\\.vscode\\extensions\\ketho.wow-api-0.13.x\\EmmyLua\\Optional"
	],
	"Lua.runtime.plugin": "C:/Users/You/wow-addons/LuaLS-Config/Plugin/Plugin.lua",
```

## Setup for CI checks

`Check-Config.lua` is a LuaLS config file to be used for running the LuaLS checker on DBM repositories. LuaLS expects to be run from its base path, so you need to invoke it like this:

```
./bin/lua-language-server \
	--checklevel Information \
	--configpath <path to this repository>/Check-Config.lua \
	--dbm_libraries <path to github.com/DeadlyBossMods/DeadlyBossMods>/DBM-Core,<path to github.com/DeadlyBossMods/DeadlyBossMods>/DBM-StatusBarTimers,<path to github.com/DeadlyBossMods/DeadlyBossMods>/DBM-Test,<Path to github.com/Ketho/vscode-wow-api>/EmmyLua \
	--trust_all_plugins \
	--check <workspace path of whatever DBM mod you want to check>
```

## FAQ

### Why is this so annoying to install and needs changes to my settings.json?

Because git submodules are terrible, so we need add workspace-external references for the library path and plugin.
Another solution would be one huge monorepo for all of DBM, but that would require a significant amount of work for the release infrastructure.

### I get lots of errors about injected fields on DBM mods, the spell ID check doesn't work and event handlers don't know their parameter types.

Check if the plugin is being loaded correctly, it will output "Loaded DBM (...)" messages to the LuaLS log (Output -> Lua in VS Code) on startup.

Make sure that your LuaLS installation is version 3.8 or newer.

### Why do we need a plugin?

Two reasons: (1) the event registration, spell ID, and sync checks are implemented as a custom diagnostic in the plugin.

And (2): Because the type system cannot express the concept of abstract base classes properly.
DBM defines boss mod base functions in `bossModPrototype` in DBM-Core, this is the class `DBMMod`.
A boss mod implementation effectively inherits from this when calling `DBM:NewMod()` and this concrete class implements things like event handlers etc.
One important feature that we are looking for is automatic inference of the types of these event handlers, i.e., a combat log event should know that it receives an args table without requiring an explicit annotation.

The type system gets us about 90% there, but it can't quite fully express this.
See [LuaLS/lua-language-server#2453](https://github.com/LuaLS/lua-language-server/issues/2453) for an example of what we can't fully express.

Also, the plugin allows us to correctly handle mods with zero additional boilerplate, it just works!
