# LuaLS setup for Deadly Boss Mods

A plugin for LuaLS that adds definitions for DBM mods dynamically.

Also adds a few extra definitions beyond what [vscode-wow-api](https://github.com/Ketho/vscode-wow-api) offers, mainly some Classic APIs and some random globals for which type information is nice to have.

## Features

**Can't remember all the NewTimer and NewAnnounce things? We got autocomplete for all of these!**

![](./Screenshots/Timers.png)

**NewTimer takes 17 parameters, do you know which is which at a glance?**

![](./Screenshots/Parameters.png)
(`Cmd+Shift+Space` in VS Code)

**Finds typos and other mistakes that are hard to spot**

![](./Screenshots/Event-Handler-Params.png)

**Auto-complete for events**

![](./Screenshots/Event-Enum.png)


## Setup for development

1. Install [Visual Studio Code](https://code.visualstudio.com/)
2. Install the [lua-language-server extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) for VS Code (Note: currently needs a patched version, see first FAQ entry below)
3. Install the [WoW API extension](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api) for VS Code
4. Clone this repo: `git clone git@github.com:DeadlyBossMods/LuaLS-Config`
5. Open VS Code's settings.json (`Cmd+Shift+P` -> "Open User Settings (JSON)")
6. Enable the DBM plugin for LuaLS to settings.json
	1. Add this line: `"Lua.runtime.plugin": "<path to where you cloned LuaLS-Config>/DBM-Plugin.lua",`
7. Add extra definitions for DBM to settings.json
	1. Find the `Lua.workspace.library` entry, it should already exist and have entries from the WoW API extension
	2. Add this line to the library array: `<path to where you cloned LuaLS-Config>/Definitions`
	3. Add this line to the library array: `<path to where you cloned the DBM-Unified repo>`

Your settings.json should look like this afterwards:

```
	"Lua.workspace.library": [
		"C:/Users/You/wow-addons/DBM-Unified",
		"C:/Users/You/wow-addons/LuaLS-Config/Definitions",
		"c:\\Users\\You\\.vscode\\extensions\\ketho.wow-api-0.13.2\\EmmyLua\\API",
		"c:\\Users\\You\\.vscode\\extensions\\ketho.wow-api-0.13.2\\EmmyLua\\Optional"
	],
	"Lua.runtime.plugin": "C:/Users/You/wow-addons/LuaLS-Config/DBM-Plugin.lua",
```

## Setup for CI checks

TODO: haven't done this yet, but it pretty much just needs a config file pointing to the right places as library and done.

## FAQ

### I get lots of errors about injected fields on DBM mods and the event handlers don't know their parameter types

Check if the plugin is being loded correctly, it will output "Loaded DBM-Plugin" to the LuaLS log on startup.

Make sure that your LuaLS installation is new enough to contain [LuaLS/lua-language-server#2502](https://github.com/LuaLS/lua-language-server/pull/2502) or an equivalent commit.
A hacky quick way to install a patched version is to just take the whole `script/` folder from my branch and copy it into the VS Code extension at `$HOME/.vscode/extensions/sumneko.lua-XYZ/server/script`.

### Why do we need a plugin?

Because the type system cannot express the concept of abstract base classes properly.
DBM defines boss mod base functions in `bossModPrototype` in DBM-Core, this is the class `DBMMod`.
A boss mod implementation effectively inherits from this when calling `DBM:NewMod()` and this concrete class implements things like event handlers etc.
One important feature that we are looking for is automatic inference of the types of these event handlers, i.e., a combat log event should know that it receives an args table without requiring an explicit annotation.

The type system gets us about 90% there, but it can't quite fully express this.
See [LuaLS/lua-language-server#2453](https://github.com/LuaLS/lua-language-server/issues/2453) for an example of what we can't fully express.

Also, the plugin allows us to correctly handle mods with zero additional boilerplate, it just works!
