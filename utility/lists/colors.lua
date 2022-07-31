-- A list of standard colors for use across mods.

-- CODE NOTE: Can't use generics on the class as then it can't spot usage of invalid ones.

local Colors = {} ---@class Utility_Colors
--https://www.rapidtables.com/web/color/html-color-codes.html
--Excel conversion string: =CONCATENATE("Colors.", B1, " = {",  SUBSTITUTE(SUBSTITUTE(D1, "(", ""),")",""), ",255} ---@type Color")
-- Custom colors can be added, but shouldn't be removed or changed.

--Custom Colors
Colors.lightRed = { 255, 100, 100, 255 } ---@type Color -- Good for red writing on GUI backgrounds.
Colors.midRed = { 255, 50, 50, 255 } ---@type Color -- Between red and lightRed, used for writing on the screen.
Colors.guiHeadingColor = { 255, 230, 192, 255 } ---@type Color

--Red
Colors.lightsalmon = { 255, 160, 122, 255 } ---@type Color
Colors.salmon = { 250, 128, 114, 255 } ---@type Color
Colors.darksalmon = { 233, 150, 122, 255 } ---@type Color
Colors.lightcoral = { 240, 128, 128, 255 } ---@type Color
Colors.indianred = { 205, 92, 92, 255 } ---@type Color
Colors.crimson = { 220, 20, 60, 255 } ---@type Color
Colors.firebrick = { 178, 34, 34, 255 } ---@type Color
Colors.red = { 255, 0, 0, 255 } ---@type Color
Colors.darkred = { 139, 0, 0, 255 } ---@type Color

--Orange
Colors.coral = { 255, 127, 80, 255 } ---@type Color
Colors.tomato = { 255, 99, 71, 255 } ---@type Color
Colors.orangered = { 255, 69, 0, 255 } ---@type Color
Colors.gold = { 255, 215, 0, 255 } ---@type Color
Colors.orange = { 255, 165, 0, 255 } ---@type Color
Colors.darkorange = { 255, 140, 0, 255 } ---@type Color

--Yellow
Colors.lightyellow = { 255, 255, 224, 255 } ---@type Color
Colors.lemonchiffon = { 255, 250, 205, 255 } ---@type Color
Colors.lightgoldenrodyellow = { 250, 250, 210, 255 } ---@type Color
Colors.papayawhip = { 255, 239, 213, 255 } ---@type Color
Colors.moccasin = { 255, 228, 181, 255 } ---@type Color
Colors.peachpuff = { 255, 218, 185, 255 } ---@type Color
Colors.palegoldenrod = { 238, 232, 170, 255 } ---@type Color
Colors.khaki = { 240, 230, 140, 255 } ---@type Color
Colors.darkkhaki = { 189, 183, 107, 255 } ---@type Color
Colors.yellow = { 255, 255, 0, 255 } ---@type Color

--Green
Colors.lawngreen = { 124, 252, 0, 255 } ---@type Color
Colors.chartreuse = { 127, 255, 0, 255 } ---@type Color
Colors.limegreen = { 50, 205, 50, 255 } ---@type Color
Colors.lime = { 0, 255, 0, 255 } ---@type Color
Colors.forestgreen = { 34, 139, 34, 255 } ---@type Color
Colors.green = { 0, 128, 0, 255 } ---@type Color
Colors.darkgreen = { 0, 100, 0, 255 } ---@type Color
Colors.greenyellow = { 173, 255, 47, 255 } ---@type Color
Colors.yellowgreen = { 154, 205, 50, 255 } ---@type Color
Colors.springgreen = { 0, 255, 127, 255 } ---@type Color
Colors.mediumspringgreen = { 0, 250, 154, 255 } ---@type Color
Colors.lightgreen = { 144, 238, 144, 255 } ---@type Color
Colors.palegreen = { 152, 251, 152, 255 } ---@type Color
Colors.darkseagreen = { 143, 188, 143, 255 } ---@type Color
Colors.mediumseagreen = { 60, 179, 113, 255 } ---@type Color
Colors.seagreen = { 46, 139, 87, 255 } ---@type Color
Colors.olive = { 128, 128, 0, 255 } ---@type Color
Colors.darkolivegreen = { 85, 107, 47, 255 } ---@type Color
Colors.olivedrab = { 107, 142, 35, 255 } ---@type Color

--Cyan
Colors.lightcyan = { 224, 255, 255, 255 } ---@type Color
Colors.cyan = { 0, 255, 255, 255 } ---@type Color
Colors.aqua = { 0, 255, 255, 255 } ---@type Color
Colors.aquamarine = { 127, 255, 212, 255 } ---@type Color
Colors.mediumaquamarine = { 102, 205, 170, 255 } ---@type Color
Colors.paleturquoise = { 175, 238, 238, 255 } ---@type Color
Colors.turquoise = { 64, 224, 208, 255 } ---@type Color
Colors.mediumturquoise = { 72, 209, 204, 255 } ---@type Color
Colors.darkturquoise = { 0, 206, 209, 255 } ---@type Color
Colors.lightseagreen = { 32, 178, 170, 255 } ---@type Color
Colors.cadetblue = { 95, 158, 160, 255 } ---@type Color
Colors.darkcyan = { 0, 139, 139, 255 } ---@type Color
Colors.teal = { 0, 128, 128, 255 } ---@type Color

--Blue
Colors.powderblue = { 176, 224, 230, 255 } ---@type Color
Colors.lightblue = { 173, 216, 230, 255 } ---@type Color
Colors.lightskyblue = { 135, 206, 250, 255 } ---@type Color
Colors.skyblue = { 135, 206, 235, 255 } ---@type Color
Colors.deepskyblue = { 0, 191, 255, 255 } ---@type Color
Colors.lightsteelblue = { 176, 196, 222, 255 } ---@type Color
Colors.dodgerblue = { 30, 144, 255, 255 } ---@type Color
Colors.cornflowerblue = { 100, 149, 237, 255 } ---@type Color
Colors.steelblue = { 70, 130, 180, 255 } ---@type Color
Colors.royalblue = { 65, 105, 225, 255 } ---@type Color
Colors.blue = { 0, 0, 255, 255 } ---@type Color
Colors.mediumblue = { 0, 0, 205, 255 } ---@type Color
Colors.darkblue = { 0, 0, 139, 255 } ---@type Color
Colors.navy = { 0, 0, 128, 255 } ---@type Color
Colors.midnightblue = { 25, 25, 112, 255 } ---@type Color
Colors.mediumslateblue = { 123, 104, 238, 255 } ---@type Color
Colors.slateblue = { 106, 90, 205, 255 } ---@type Color
Colors.darkslateblue = { 72, 61, 139, 255 } ---@type Color

--Purple
Colors.lavender = { 230, 230, 250, 255 } ---@type Color
Colors.thistle = { 216, 191, 216, 255 } ---@type Color
Colors.plum = { 221, 160, 221, 255 } ---@type Color
Colors.violet = { 238, 130, 238, 255 } ---@type Color
Colors.orchid = { 218, 112, 214, 255 } ---@type Color
Colors.fuchsia = { 255, 0, 255, 255 } ---@type Color
Colors.magenta = { 255, 0, 255, 255 } ---@type Color
Colors.mediumorchid = { 186, 85, 211, 255 } ---@type Color
Colors.mediumpurple = { 147, 112, 219, 255 } ---@type Color
Colors.blueviolet = { 138, 43, 226, 255 } ---@type Color
Colors.darkviolet = { 148, 0, 211, 255 } ---@type Color
Colors.darkorchid = { 153, 50, 204, 255 } ---@type Color
Colors.darkmagenta = { 139, 0, 139, 255 } ---@type Color
Colors.purple = { 128, 0, 128, 255 } ---@type Color
Colors.indigo = { 75, 0, 130, 255 } ---@type Color

--Pink
Colors.pink = { 255, 192, 203, 255 } ---@type Color
Colors.lightpink = { 255, 182, 193, 255 } ---@type Color
Colors.hotpink = { 255, 105, 180, 255 } ---@type Color
Colors.deeppink = { 255, 20, 147, 255 } ---@type Color
Colors.palevioletred = { 219, 112, 147, 255 } ---@type Color
Colors.mediumvioletred = { 199, 21, 133, 255 } ---@type Color

--White
Colors.white = { 255, 255, 255, 255 } ---@type Color
Colors.snow = { 255, 250, 250, 255 } ---@type Color
Colors.honeydew = { 240, 255, 240, 255 } ---@type Color
Colors.mintcream = { 245, 255, 250, 255 } ---@type Color
Colors.azure = { 240, 255, 255, 255 } ---@type Color
Colors.aliceblue = { 240, 248, 255, 255 } ---@type Color
Colors.ghostwhite = { 248, 248, 255, 255 } ---@type Color
Colors.whitesmoke = { 245, 245, 245, 255 } ---@type Color
Colors.seashell = { 255, 245, 238, 255 } ---@type Color
Colors.beige = { 245, 245, 220, 255 } ---@type Color
Colors.oldlace = { 253, 245, 230, 255 } ---@type Color
Colors.floralwhite = { 255, 250, 240, 255 } ---@type Color
Colors.ivory = { 255, 255, 240, 255 } ---@type Color
Colors.antiquewhite = { 250, 235, 215, 255 } ---@type Color
Colors.linen = { 250, 240, 230, 255 } ---@type Color
Colors.lavenderblush = { 255, 240, 245, 255 } ---@type Color
Colors.mistyrose = { 255, 228, 225, 255 } ---@type Color

--Grey
Colors.gainsboro = { 220, 220, 220, 255 } ---@type Color
Colors.lightgrey = { 211, 211, 211, 255 } ---@type Color
Colors.silver = { 192, 192, 192, 255 } ---@type Color
Colors.darkgrey = { 169, 169, 169, 255 } ---@type Color
Colors.grey = { 128, 128, 128, 255 } ---@type Color
Colors.dimgrey = { 105, 105, 105, 255 } ---@type Color
Colors.lightslategrey = { 119, 136, 153, 255 } ---@type Color
Colors.slategrey = { 112, 128, 144, 255 } ---@type Color
Colors.darkslategrey = { 47, 79, 79, 255 } ---@type Color
Colors.black = { 0, 0, 0, 255 } ---@type Color

--Brown
Colors.cornsilk = { 255, 248, 220, 255 } ---@type Color
Colors.blanchedalmond = { 255, 235, 205, 255 } ---@type Color
Colors.bisque = { 255, 228, 196, 255 } ---@type Color
Colors.navajowhite = { 255, 222, 173, 255 } ---@type Color
Colors.wheat = { 245, 222, 179, 255 } ---@type Color
Colors.burlywood = { 222, 184, 135, 255 } ---@type Color
Colors.tan = { 210, 180, 140, 255 } ---@type Color
Colors.rosybrown = { 188, 143, 143, 255 } ---@type Color
Colors.sandybrown = { 244, 164, 96, 255 } ---@type Color
Colors.goldenrod = { 218, 165, 32, 255 } ---@type Color
Colors.peru = { 205, 133, 63, 255 } ---@type Color
Colors.chocolate = { 210, 105, 30, 255 } ---@type Color
Colors.saddlebrown = { 139, 69, 19, 255 } ---@type Color
Colors.sienna = { 160, 82, 45, 255 } ---@type Color
Colors.brown = { 165, 42, 42, 255 } ---@type Color
Colors.maroon = { 128, 0, 0, 255 } ---@type Color

-- Named presets - Must be last so we can reference already added values.
Colors.errorMessage = Colors.midRed
Colors.warningMessage = Colors.orange

return Colors
