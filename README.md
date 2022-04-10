# SmoothScroll
Customizable smooth scrolling for Roblox ScrollingFrames

## Deprecation Notice

In [Update 421](https://devforum.roblox.com/t/release-notes-for-421/468953), Roblox added smooth scrolling to ScrollingFrames.
However, Roblox did not give us the ability to adjust scroll speed or friction, so this module still has some utility.

We had a good long run here, and I know this module helped a lot of people while it was around. I hope you all benefited from it, and I'm glad to see Roblox improving the platform so modules like these are unnecessary!

> I'm certain that one day, Roblox will make this behavior the default. Until that day, this is what I'll be using!

^ Just saying, I called it.

# API

Implementation and usage is incredibly easy. You use regular ScrollingFrames when creating your GUIs, and just tell the module to make it smooth. It does the rest!

*(I used [Rodocs](https://devforum.roblox.com/t/documentation-reader-a-plugin-for-scripters/128825) to document the module, and I highly recommend it.)*


```Lua
function SmoothScroll.Enable(Frame, Sensitivity, Friction, Inverted, Axis)
```
*Sets a ScrollingFrame to scroll smoothly*

**Parameters:**
- `Frame` *[ScrollingFrame]*
The ScrollingFrame object to apply smoothing to

- `Sensitivity` *[Optional Number]*
How many pixels it scrolls per wheel turn
- `Friction` *[Optional Number]*
What the velocity is multiplied by each frame *(Clamped between 0.2 and 0.99)*
- `Inverted` *[Optional Bool]*
Inverts the scrolling direction
- `Axis` *[Optional String]*
"X" or "Y". If left out, will default to whichever Axis is scrollable or "Y" if both are valid

**Returns:**  
* `void`

```Lua
function SmoothScroll.Disable(Frame)
```
*Sets a ScrollingFrame to scroll normally*

**Parameters:**
- `Frame` *[ScrollingFrame]*
The ScrollingFrame object to remove smoothing from

**Returns:**  
* `void`

# Examples

It's super simple to use. It's also coded defensively, so even if you mess up, it'll either use default or just 'warn' and not smooth it. This means the module should never halt or break your code. If you find an error case that does, let me know!

Simple use example:
```Lua
local SmoothScroll	= require(script.SmoothScroll)

local ScreenGui		= game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")

SmoothScroll.Enable(ScreenGui.ScrollingFrame)
```

This example automatically smooths any ScrollingFrame in your game except ones that you tag with "DontSmooth" via ColectionService. This code is was used in production in Lua Learning! It's super useful.

```Lua
local CollectionService = game:GetService("CollectionService")

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local SmoothScroll = require(script.SmoothScroll)

local Smoothed = {}

local function DescendantAdded(Descendant)
	if Descendant:IsA("ScrollingFrame") and not Smoothed[Descendant] and not CollectionService:HasTag(Descendant, "DontSmooth") then
		SmoothScroll.Enable(Descendant)
		Smoothed[Descendant] = true
	end
end

local function DescendantRemoving(Descendant)
	if Descendant:IsA("ScrollingFrame") and Smoothed[Descendant] then
		SmoothScroll.Disable(Descendant)
		Smoothed[Descendant] = nil
	end
end

-- Initialize

for _, Descendant in pairs(PlayerGui:GetDescendants()) do
	DescendantAdded(Descendant)
end

PlayerGui.DescendantAdded:Connect(DescendantAdded)
PlayerGui.DescendantRemoving:Connect(DescendantRemoving)
```
