--[[
    Contains the default style prototypes for GUIs I use in mods. WARNING: adds directly to game prototypes and so is not self contained within each mod instance, version mismatch can cause overwriting in rare scenarios.

    "margin" and "padded" are 4 pixels. Margin offsets on the top and left of the outside of the element. Padded keeps inside things away from the bottom and right of the elements. Unlimited things with margin should be stackable inside the padded thing. Margin and Padded combines both for elements that are inside others and have their own contents.

    These styles are intended to be called by gui-util which will handle adding the version number to the end of style names.

    This file is now version controlled to avoid conflicts with different versions used by different mods.

    Require the file and call GeneratePrototypes() in data.lua:
        require("utility.lists.style-data").GeneratePrototypes()

    Require the file and obtain the MuppetStyles dictionary in any usage scenarios (lua files) to get autocomplete list of all the styles and their options. Saves having to remember them or check which options are available in this source code.
        local MuppetStyles = require("utility.lists.style-data").MuppetStyles
        local MuppetFonts = require("utility.lists.style-data").MuppetFonts
    If a sub field is available in the autocomplete list then one must be selected, otherwise you will end up with a blank style at runtime. For this reason (and simplicity) the margin, padding and other optional settings are just a single string with each combination covered.
        i.e: MuppetStyles.flow.vertical.marginTL_spaced
    The final type of "plain" is with no padding, margin, etc. Its provided to comply with the above statement that a style autocomplete entry is only valid if you reach the end of the sub options list.
]]
--

-- CODE NOTE: at present the data stage prototypes for GuiStyle are too incomplete to be added to this. 2022-07-26.

local StyleData = {} ---@class Utility_StyleData

local Colors = require("utility.lists.colors")

StyleData.styleVersion = "_1_1_0"
local styleNamesGenerated = {} ---@type table<string, table>

-- Enable to write the styles out to a text file to use for updating EmmyLua class. This is for when updating the styles library only during development.
-- Doesn't include Style version as we don't want to hardcode that in to usage code.
local writeStyleNames = false

local GenerateDetailsName = function(detailsName)
    local generatedDetailsName = string.gsub(detailsName, "_", "", 1)
    if generatedDetailsName == "" then
        generatedDetailsName = "plain"
    end
    return generatedDetailsName
end

--- Call in data.lua to actually generate the styles in to the game's prototypes.
StyleData.GeneratePrototypes = function()
    local defaultStyle = data.raw["gui-style"]["default"] ---@type table<string, table<string|uint, any>>

    local frameShadowRisenColor = { 0, 0, 0, 0.35 }
    local frameShadowSunkenColor = { 0, 0, 0, 1 }
    local frameShadowRisen = function()
        return {
            position = { 183, 128 },
            corner_size = 8,
            tint = frameShadowRisenColor,
            scale = 0.5,
            draw_type = "inner"
        }
    end
    local frameShadowSunken = function()
        return {
            position = { 200, 128 },
            corner_size = 8,
            tint = frameShadowSunkenColor,
            scale = 0.5,
            draw_type = "outer"
        }
    end

    -- FLOW
    styleNamesGenerated.flow = {} ---@type table<string, table<string, string>>
    for _, direction in pairs({ { "_horizontal", "horizontal" }, { "_vertical", "vertical" } }) do
        styleNamesGenerated.flow[direction[2]] = {}
        for _, margin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
            for _, padding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 } }) do
                for _, spacing in pairs({ { "", 0 }, { "_spaced", 4 } }) do
                    local detailsName = margin[1] .. padding[1] .. spacing[1]
                    local styleName = "muppet_flow" .. direction[1] .. detailsName
                    defaultStyle[styleName .. StyleData.styleVersion] = {
                        type = direction[2] .. "_flow_style",
                        left_margin = margin[2],
                        top_margin = margin[3],
                        right_margin = margin[4],
                        bottom_margin = margin[5],
                        left_padding = padding[2],
                        top_padding = padding[3],
                        right_padding = padding[4],
                        bottom_padding = padding[5],
                        [direction[2] .. "_spacing"] = spacing[2]
                    }
                    styleNamesGenerated.flow[direction[2]][GenerateDetailsName(detailsName)] = styleName
                end
            end
        end
    end

    -- FRAME - the shadow types include padding/margins to handle the graphics. take this in to account if overwriting the values.
    styleNamesGenerated.frame = {} ---@type table<string, table<string, string>>
    for _, graphic in pairs(
        {
            { "_main", { base = { position = { 0, 0 }, corner_size = 8 } }, 0, 0 },
            { "_main_shadowSunken", { base = { position = { 0, 0 }, corner_size = 8 }, shadow = frameShadowSunken() }, 2, 0 },
            { "_main_shadowRisen", { base = { position = { 0, 0 }, corner_size = 8 }, shadow = frameShadowRisen() }, 0, 2 },
            { "_content", { base = { position = { 68, 0 }, corner_size = 8 } }, 0, 0 },
            { "_content_shadowSunken", { base = { position = { 68, 0 }, corner_size = 8 }, shadow = frameShadowSunken() }, 2, 0 },
            { "_content_shadowRisen", { base = { position = { 68, 0 }, corner_size = 8 }, shadow = frameShadowRisen() }, 0, 2 },
            { "_contentInnerDark", { base = { position = { 34, 0 }, corner_size = 8 } }, 0, 0 },
            { "_contentInnerDark_shadowSunken", { base = { position = { 34, 0 }, corner_size = 8 }, shadow = frameShadowSunken() }, 2, 0 },
            { "_contentInnerDark_shadowRisen", { base = { position = { 34, 0 }, corner_size = 8 }, shadow = frameShadowRisen() }, 0, 2 },
            { "_contentInnerLight", { base = { position = { 0, 17 }, corner_size = 8 } }, 0, 0 },
            { "_contentInnerLight_shadowSunken", { base = { position = { 0, 17 }, corner_size = 8 }, shadow = frameShadowSunken() }, 2, 0 },
            { "_contentInnerLight_shadowRisen", { base = { position = { 0, 17 }, corner_size = 8 }, shadow = frameShadowRisen() }, 0, 2 }
        }
    ) do
        local graphicEmmyLuaName = string.sub(graphic[1], 2)
        styleNamesGenerated.frame[graphicEmmyLuaName] = {}
        for _, margin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
            for _, padding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 } }) do
                local detailsName = margin[1] .. padding[1]
                local styleName = "muppet_frame" .. graphic[1] .. detailsName
                defaultStyle[styleName .. StyleData.styleVersion] = {
                    type = "frame_style",
                    left_margin = margin[2] + graphic[3],
                    top_margin = margin[3] + graphic[3],
                    right_margin = margin[4] + graphic[3],
                    bottom_margin = margin[5] + graphic[3],
                    left_padding = padding[2] + graphic[4],
                    top_padding = padding[3] + graphic[4],
                    right_padding = padding[4] + graphic[4],
                    bottom_padding = padding[5] + graphic[4],
                    graphical_set = graphic[2]
                }
                styleNamesGenerated.frame[graphicEmmyLuaName][GenerateDetailsName(detailsName)] = styleName
            end
        end
    end

    -- SCROLL
    styleNamesGenerated.scroll = {} ---@type table<string, string>
    for _, margin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
        for _, padding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 } }) do
            local detailsName = margin[1] .. padding[1]
            local styleName = "muppet_scroll" .. detailsName
            defaultStyle[styleName .. StyleData.styleVersion] = {
                type = "scroll_pane_style",
                left_margin = 2 + margin[2],
                top_margin = 2 + margin[3],
                right_margin = 2 + margin[4],
                bottom_margin = 2 + margin[5],
                left_padding = padding[2],
                top_padding = padding[3],
                right_padding = padding[4],
                bottom_padding = padding[5],
                extra_left_padding_when_activated = 0,
                extra_top_padding_when_activated = 0,
                extra_right_padding_when_activated = 0,
                extra_bottom_padding_when_activated = 0
            }
            styleNamesGenerated.scroll[GenerateDetailsName(detailsName)] = styleName
        end
    end

    -- TABLE
    styleNamesGenerated.table = {} ---@type table<string, string>
    for _, tableMargin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
        for _, tablePadding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 } }) do
            for _, cellPadding in pairs({ { "", 0, 0, 0, 0 }, { "_cellPadded", 4, 4, 4, 4 } }) do
                for _, verticalSpaced in pairs({ { "", 0 }, { "_verticalSpaced", 4 } }) do
                    for _, horizontalSpaced in pairs({ { "", 0 }, { "_horizontalSpaced", 4 } }) do
                        local detailsName = tableMargin[1] .. tablePadding[1] .. cellPadding[1] .. verticalSpaced[1] .. horizontalSpaced[1]
                        local styleName = "muppet_table" .. detailsName
                        defaultStyle[styleName .. StyleData.styleVersion] = {
                            type = "table_style",
                            left_margin = tableMargin[2],
                            top_margin = tableMargin[3],
                            right_margin = tableMargin[4],
                            bottom_margin = tableMargin[5],
                            left_padding = tablePadding[2],
                            top_padding = tablePadding[3],
                            right_padding = tablePadding[4],
                            bottom_padding = tablePadding[5],
                            left_cell_padding = cellPadding[2],
                            top_cell_padding = cellPadding[3],
                            right_cell_padding = cellPadding[4],
                            bottom_cell_padding = cellPadding[5],
                            vertical_spacing = verticalSpaced[2],
                            horizontal_spacing = horizontalSpaced[2]
                        }
                        styleNamesGenerated.table[GenerateDetailsName(detailsName)] = styleName
                    end
                end
            end
        end
    end

    -- SPRITE
    styleNamesGenerated.sprite = {} ---@type table<string, string>
    for _, size in pairs({ { "_32", 32 }, { "_48", 48 }, { "_64", 64 } }) do
        local detailsName = size[1]
        local styleName = "muppet_sprite" .. detailsName
        defaultStyle[styleName .. StyleData.styleVersion] = {
            type = "image_style",
            width = size[2],
            height = size[2],
            margin = 0,
            padding = 0,
            stretch_image_to_widget_size = true
        }
        styleNamesGenerated.sprite[GenerateDetailsName(detailsName)] = styleName
    end

    -- SPRITE BUTTON
    styleNamesGenerated.spriteButton = {} ---@type table<string, string>
    for _, attributes in pairs(
        {
            { "", {} },
            { "_frame", { default_graphical_set = { base = { position = { 0, 0 }, corner_size = 8 }, shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" } } } },
            { "_noBorder", { default_graphical_set = {}, hovered_graphical_set = {}, clicked_graphical_set = {} } },
            { "_frameCloseButtonClickable", { default_graphical_set = { base = { position = { 0, 0 }, corner_size = 8 }, shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" } }, padding = -6, width = 16, height = 16 } }
        }
    ) do
        for _, size in pairs({ { "", nil }, { "_mod", 36 }, { "_smallText", 28 }, { "_clickable", 16 }, { "_32", 32 }, { "_48", 48 }, { "_64", 64 } }) do
            local detailsName = attributes[1] .. size[1]
            local styleName = "muppet_sprite_button" .. detailsName
            local styleNameVersion = styleName .. StyleData.styleVersion
            defaultStyle[styleNameVersion] = {
                type = "button_style",
                width = size[2] --[[@as uint|nil]] ,
                height = size[2] --[[@as uint|nil]] ,
                margin = 0,
                padding = 0
            }
            for k, v in pairs(attributes[2]--[[@as table<string, table>]] ) do
                if type(k) == "number" then ---@cast k uint # It's really a uint value if its a number type.
                    defaultStyle[styleNameVersion][k] = (defaultStyle[styleNameVersion][k] or 0) + v
                else
                    defaultStyle[styleNameVersion][k] = v
                end
            end
            styleNamesGenerated.spriteButton[GenerateDetailsName(detailsName)] = styleName
        end
    end

    -- BUTTON
    styleNamesGenerated.button = {} ---@type table<string, table<string, string>>
    for _, textSize in pairs({ { "_small", "_small" }, { "_medium", "_medium" }, { "_large", "_large" } }) do
        local textSizeEmmyLuaName = string.sub(textSize[1], 2)
        styleNamesGenerated.button[textSizeEmmyLuaName] = {}
        for _, boldness in pairs({ { "", "" }, { "_semibold", "_semibold" }, { "_bold", "_bold" } }) do
            for _, attributes in pairs(
                {
                    { "", {} },
                    { "_frame", { default_graphical_set = { base = { position = { 0, 0 }, corner_size = 8 }, shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" } }, default_font_color = Colors.white, hovered_font_color = Colors.white, clicked_font_color = Colors.white } },
                    { "_noBorder", { default_graphical_set = {}, hovered_graphical_set = {}, clicked_graphical_set = {} } }
                }
            ) do
                for _, padding in pairs({ { "", 0, -2, 0, -2 }, { "_paddingSides", 4, 0, 4, 0 }, { "_paddingNone", -2, -6, -2, -6 }, { "_paddingTight", 0, -4, 0, -4 } }) do
                    local detailsName = boldness[1] .. attributes[1] .. padding[1]
                    local styleName = "muppet_button_text" .. textSize[1] .. detailsName
                    local styleNameVersion = styleName .. StyleData.styleVersion
                    defaultStyle[styleNameVersion] = {
                        type = "button_style",
                        font = "muppet" .. textSize[2] .. boldness[2] .. StyleData.styleVersion,
                        margin = 0,
                        left_padding = padding[2],
                        top_padding = padding[3],
                        right_padding = padding[4],
                        bottom_padding = padding[5],
                        minimal_width = 0,
                        minimal_height = 0
                    }
                    for k, v in pairs(attributes[2]--[[@as table<string, table>]] ) do
                        if type(k) == "number" then ---@cast k uint # It's really a uint value if its a number type.
                            defaultStyle[styleNameVersion][k] = (defaultStyle[styleNameVersion][k] or 0) + v
                        else
                            defaultStyle[styleNameVersion][k] = v
                        end
                    end
                    styleNamesGenerated.button[textSizeEmmyLuaName][GenerateDetailsName(detailsName)] = styleName
                end
            end
        end
    end

    -- LABEL
    styleNamesGenerated.label = {} ---@type table<string, table<string, table<string, string>>>
    for _, purpose in pairs({ { "_text", Colors.white }, { "_heading", Colors.guiHeadingColor } }) do
        local purposeEmmyLuaName = string.sub(purpose[1], 2)
        styleNamesGenerated.label[purposeEmmyLuaName] = {}
        for _, textSize in pairs({ { "_small", "_small" }, { "_medium", "_medium" }, { "_large", "_large" } }) do
            local textSizeEmmyLuaName = string.sub(textSize[1], 2)
            styleNamesGenerated.label[purposeEmmyLuaName][textSizeEmmyLuaName] = {}
            for _, boldness in pairs({ { "", "" }, { "_semibold", "_semibold" }, { "_bold", "_bold" } }) do
                for _, margin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
                    for _, padding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 }, { "_paddingSides", 4, 0, 4, 0 } }) do
                        local detailsName = boldness[1] .. margin[1] .. padding[1]
                        local styleName = "muppet_label" .. purpose[1] .. textSize[1] .. detailsName
                        defaultStyle[styleName .. StyleData.styleVersion] = {
                            type = "label_style",
                            font = "muppet" .. textSize[2] .. boldness[2] .. StyleData.styleVersion,
                            font_color = purpose[2],
                            single_line = false,
                            left_margin = margin[2],
                            top_margin = margin[3],
                            right_margin = margin[4],
                            bottom_margin = margin[5],
                            left_padding = padding[2],
                            top_padding = padding[3],
                            right_padding = padding[4],
                            bottom_padding = padding[5]
                        }
                        styleNamesGenerated.label[purposeEmmyLuaName][textSizeEmmyLuaName][GenerateDetailsName(detailsName)] = styleName
                    end
                end
            end
        end
    end

    -- TEXT BOX - set width & height setting when using as base game has values that can't be nil'd
    styleNamesGenerated.textbox = {} ---@type table<string, string>
    for _, margin in pairs({ { "", 0, 0, 0, 0 }, { "_marginTL", 4, 4, 0, 0 } }) do
        for _, padding in pairs({ { "", 0, 0, 0, 0 }, { "_paddingBR", 0, 0, 4, 4 } }) do
            local detailsName = margin[1] .. padding[1]
            local styleName = "muppet_textbox" .. detailsName
            defaultStyle[styleName .. StyleData.styleVersion] = {
                type = "textbox_style",
                left_margin = margin[2],
                top_margin = margin[3],
                right_margin = margin[4],
                bottom_margin = margin[5],
                left_padding = padding[2],
                top_padding = padding[3],
                right_padding = padding[4],
                bottom_padding = padding[5]
            }
            styleNamesGenerated.textbox[GenerateDetailsName(detailsName)] = styleName
        end
    end

    ---@type Prototype.Font[]
    local muppetFonts = {
        {
            type = "font",
            name = "muppet_small" .. StyleData.styleVersion,
            from = "default",
            size = 12
        },
        {
            type = "font",
            name = "muppet_small_semibold" .. StyleData.styleVersion,
            from = "default-semibold",
            size = 12
        },
        {
            type = "font",
            name = "muppet_small_bold" .. StyleData.styleVersion,
            from = "default-bold",
            size = 12
        },
        {
            type = "font",
            name = "muppet_medium" .. StyleData.styleVersion,
            from = "default",
            size = 16
        },
        {
            type = "font",
            name = "muppet_medium_semibold" .. StyleData.styleVersion,
            from = "default-semibold",
            size = 16
        },
        {
            type = "font",
            name = "muppet_medium_bold" .. StyleData.styleVersion,
            from = "default-bold",
            size = 16
        },
        {
            type = "font",
            name = "muppet_large" .. StyleData.styleVersion,
            from = "default",
            size = 18
        },
        {
            type = "font",
            name = "muppet_large_semibold" .. StyleData.styleVersion,
            from = "default-semibold",
            size = 18
        },
        {
            type = "font",
            name = "muppet_large_bold" .. StyleData.styleVersion,
            from = "default-bold",
            size = 18
        }
    }
    data:extend(muppetFonts)

    -- Write out the generated styles and fonts if enabled to the log. Can't write to a text file as no "game" object at data stage.
    if writeStyleNames then
        -- Write out the style data to the log for all the styles we generated.
        local text = "\r\n\r\n\r\n" .. "---@class UtilityGuiStyle_MuppetStyle" .. "\r\n" .. "StyleData.MuppetStyles = {" .. "\r\n"
        for typeName, styles in pairs(styleNamesGenerated) do
            text = text .. typeName .. " = {" .. "\r\n"
            text = text .. StyleData._TraverseStyleChildrenToString(styles)
            text = text .. "}," .. "\r\n"
        end
        text = text .. "}" .. "\r\n"

        -- Write out the font data to the log for all the fonts we generated.
        text = text .. "\r\n" .. "---@class UtilityGuiStyle_MuppetFonts" .. "\r\n" .. "StyleData.MuppetFonts = {" .. "\r\n"
        for _, font in pairs(muppetFonts) do
            text = text .. font.name .. ' = "' .. font.name .. '", ' .. "\r\n"
        end
        text = text .. "}" .. "\r\n\r\n\r\n"

        log(tostring(text))
    end
end

--- Traverse the variable nesting layers of the muppet styles and make a Lua object string for them.
---@param styleChildren table<string, string|table> # A dictionary of the current style children.
StyleData._TraverseStyleChildrenToString = function(styleChildren)
    local text = ""
    for styleDetailsName, styleFullName in pairs(styleChildren) do
        if type(styleFullName) == "string" then
            -- No extra nesting levels.
            text = text .. '["' .. styleDetailsName .. '"] = ' .. '"' .. styleFullName .. '",' .. "\r\n"
        else
            -- Another layer of nesting
            text = text .. styleDetailsName .. " = {" .. "\r\n"
            text = text .. StyleData._TraverseStyleChildrenToString(styleFullName)
            text = text .. "}," .. "\r\n"
        end
    end
    return text
end

--- The style options pre-defined by Muppet Utils. For use in runtime code by IDE's to auto select pre-defined style names.
---@class UtilityGuiStyle_MuppetStyle
StyleData.MuppetStyles = {
    flow = {
        horizontal = {
            ["plain"] = "muppet_flow_horizontal",
            ["spaced"] = "muppet_flow_horizontal_spaced",
            ["paddingBR"] = "muppet_flow_horizontal_paddingBR",
            ["paddingBR_spaced"] = "muppet_flow_horizontal_paddingBR_spaced",
            ["marginTL"] = "muppet_flow_horizontal_marginTL",
            ["marginTL_spaced"] = "muppet_flow_horizontal_marginTL_spaced",
            ["marginTL_paddingBR"] = "muppet_flow_horizontal_marginTL_paddingBR",
            ["marginTL_paddingBR_spaced"] = "muppet_flow_horizontal_marginTL_paddingBR_spaced"
        },
        vertical = {
            ["plain"] = "muppet_flow_vertical",
            ["spaced"] = "muppet_flow_vertical_spaced",
            ["paddingBR"] = "muppet_flow_vertical_paddingBR",
            ["paddingBR_spaced"] = "muppet_flow_vertical_paddingBR_spaced",
            ["marginTL"] = "muppet_flow_vertical_marginTL",
            ["marginTL_spaced"] = "muppet_flow_vertical_marginTL_spaced",
            ["marginTL_paddingBR"] = "muppet_flow_vertical_marginTL_paddingBR",
            ["marginTL_paddingBR_spaced"] = "muppet_flow_vertical_marginTL_paddingBR_spaced"
        }
    },
    frame = {
        main = {
            ["plain"] = "muppet_frame_main",
            ["paddingBR"] = "muppet_frame_main_paddingBR",
            ["marginTL"] = "muppet_frame_main_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_main_marginTL_paddingBR"
        },
        main_shadowSunken = {
            ["plain"] = "muppet_frame_main_shadowSunken",
            ["paddingBR"] = "muppet_frame_main_shadowSunken_paddingBR",
            ["marginTL"] = "muppet_frame_main_shadowSunken_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_main_shadowSunken_marginTL_paddingBR"
        },
        main_shadowRisen = {
            ["plain"] = "muppet_frame_main_shadowRisen",
            ["paddingBR"] = "muppet_frame_main_shadowRisen_paddingBR",
            ["marginTL"] = "muppet_frame_main_shadowRisen_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_main_shadowRisen_marginTL_paddingBR"
        },
        content = {
            ["plain"] = "muppet_frame_content",
            ["paddingBR"] = "muppet_frame_content_paddingBR",
            ["marginTL"] = "muppet_frame_content_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_content_marginTL_paddingBR"
        },
        content_shadowSunken = {
            ["plain"] = "muppet_frame_content_shadowSunken",
            ["paddingBR"] = "muppet_frame_content_shadowSunken_paddingBR",
            ["marginTL"] = "muppet_frame_content_shadowSunken_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_content_shadowSunken_marginTL_paddingBR"
        },
        content_shadowRisen = {
            ["plain"] = "muppet_frame_content_shadowRisen",
            ["paddingBR"] = "muppet_frame_content_shadowRisen_paddingBR",
            ["marginTL"] = "muppet_frame_content_shadowRisen_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_content_shadowRisen_marginTL_paddingBR"
        },
        contentInnerDark = {
            ["plain"] = "muppet_frame_contentInnerDark",
            ["paddingBR"] = "muppet_frame_contentInnerDark_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerDark_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerDark_marginTL_paddingBR"
        },
        contentInnerDark_shadowSunken = {
            ["plain"] = "muppet_frame_contentInnerDark_shadowSunken",
            ["paddingBR"] = "muppet_frame_contentInnerDark_shadowSunken_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerDark_shadowSunken_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerDark_shadowSunken_marginTL_paddingBR"
        },
        contentInnerDark_shadowRisen = {
            ["plain"] = "muppet_frame_contentInnerDark_shadowRisen",
            ["paddingBR"] = "muppet_frame_contentInnerDark_shadowRisen_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerDark_shadowRisen_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerDark_shadowRisen_marginTL_paddingBR"
        },
        contentInnerLight = {
            ["plain"] = "muppet_frame_contentInnerLight",
            ["paddingBR"] = "muppet_frame_contentInnerLight_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerLight_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerLight_marginTL_paddingBR"
        },
        contentInnerLight_shadowSunken = {
            ["plain"] = "muppet_frame_contentInnerLight_shadowSunken",
            ["paddingBR"] = "muppet_frame_contentInnerLight_shadowSunken_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerLight_shadowSunken_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerLight_shadowSunken_marginTL_paddingBR"
        },
        contentInnerLight_shadowRisen = {
            ["plain"] = "muppet_frame_contentInnerLight_shadowRisen",
            ["paddingBR"] = "muppet_frame_contentInnerLight_shadowRisen_paddingBR",
            ["marginTL"] = "muppet_frame_contentInnerLight_shadowRisen_marginTL",
            ["marginTL_paddingBR"] = "muppet_frame_contentInnerLight_shadowRisen_marginTL_paddingBR"
        }
    },
    scroll = {
        ["plain"] = "muppet_scroll",
        ["paddingBR"] = "muppet_scroll_paddingBR",
        ["marginTL"] = "muppet_scroll_marginTL",
        ["marginTL_paddingBR"] = "muppet_scroll_marginTL_paddingBR"
    },
    table = {
        ["plain"] = "muppet_table",
        ["horizontalSpaced"] = "muppet_table_horizontalSpaced",
        ["verticalSpaced"] = "muppet_table_verticalSpaced",
        ["verticalSpaced_horizontalSpaced"] = "muppet_table_verticalSpaced_horizontalSpaced",
        ["cellPadded"] = "muppet_table_cellPadded",
        ["cellPadded_horizontalSpaced"] = "muppet_table_cellPadded_horizontalSpaced",
        ["cellPadded_verticalSpaced"] = "muppet_table_cellPadded_verticalSpaced",
        ["cellPadded_verticalSpaced_horizontalSpaced"] = "muppet_table_cellPadded_verticalSpaced_horizontalSpaced",
        ["paddingBR"] = "muppet_table_paddingBR",
        ["paddingBR_horizontalSpaced"] = "muppet_table_paddingBR_horizontalSpaced",
        ["paddingBR_verticalSpaced"] = "muppet_table_paddingBR_verticalSpaced",
        ["paddingBR_verticalSpaced_horizontalSpaced"] = "muppet_table_paddingBR_verticalSpaced_horizontalSpaced",
        ["paddingBR_cellPadded"] = "muppet_table_paddingBR_cellPadded",
        ["paddingBR_cellPadded_horizontalSpaced"] = "muppet_table_paddingBR_cellPadded_horizontalSpaced",
        ["paddingBR_cellPadded_verticalSpaced"] = "muppet_table_paddingBR_cellPadded_verticalSpaced",
        ["paddingBR_cellPadded_verticalSpaced_horizontalSpaced"] = "muppet_table_paddingBR_cellPadded_verticalSpaced_horizontalSpaced",
        ["marginTL"] = "muppet_table_marginTL",
        ["marginTL_horizontalSpaced"] = "muppet_table_marginTL_horizontalSpaced",
        ["marginTL_verticalSpaced"] = "muppet_table_marginTL_verticalSpaced",
        ["marginTL_verticalSpaced_horizontalSpaced"] = "muppet_table_marginTL_verticalSpaced_horizontalSpaced",
        ["marginTL_cellPadded"] = "muppet_table_marginTL_cellPadded",
        ["marginTL_cellPadded_horizontalSpaced"] = "muppet_table_marginTL_cellPadded_horizontalSpaced",
        ["marginTL_cellPadded_verticalSpaced"] = "muppet_table_marginTL_cellPadded_verticalSpaced",
        ["marginTL_cellPadded_verticalSpaced_horizontalSpaced"] = "muppet_table_marginTL_cellPadded_verticalSpaced_horizontalSpaced",
        ["marginTL_paddingBR"] = "muppet_table_marginTL_paddingBR",
        ["marginTL_paddingBR_horizontalSpaced"] = "muppet_table_marginTL_paddingBR_horizontalSpaced",
        ["marginTL_paddingBR_verticalSpaced"] = "muppet_table_marginTL_paddingBR_verticalSpaced",
        ["marginTL_paddingBR_verticalSpaced_horizontalSpaced"] = "muppet_table_marginTL_paddingBR_verticalSpaced_horizontalSpaced",
        ["marginTL_paddingBR_cellPadded"] = "muppet_table_marginTL_paddingBR_cellPadded",
        ["marginTL_paddingBR_cellPadded_horizontalSpaced"] = "muppet_table_marginTL_paddingBR_cellPadded_horizontalSpaced",
        ["marginTL_paddingBR_cellPadded_verticalSpaced"] = "muppet_table_marginTL_paddingBR_cellPadded_verticalSpaced",
        ["marginTL_paddingBR_cellPadded_verticalSpaced_horizontalSpaced"] = "muppet_table_marginTL_paddingBR_cellPadded_verticalSpaced_horizontalSpaced"
    },
    sprite = {
        ["32"] = "muppet_sprite_32",
        ["48"] = "muppet_sprite_48",
        ["64"] = "muppet_sprite_64"
    },
    spriteButton = {
        ["plain"] = "muppet_sprite_button",
        ["mod"] = "muppet_sprite_button_mod",
        ["smallText"] = "muppet_sprite_button_smallText",
        ["clickable"] = "muppet_sprite_button_clickable",
        ["32"] = "muppet_sprite_button_32",
        ["48"] = "muppet_sprite_button_48",
        ["64"] = "muppet_sprite_button_64",
        ["frame"] = "muppet_sprite_button_frame",
        ["frame_mod"] = "muppet_sprite_button_frame_mod",
        ["frame_smallText"] = "muppet_sprite_button_frame_smallText",
        ["frame_clickable"] = "muppet_sprite_button_frame_clickable",
        ["frame_32"] = "muppet_sprite_button_frame_32",
        ["frame_48"] = "muppet_sprite_button_frame_48",
        ["frame_64"] = "muppet_sprite_button_frame_64",
        ["noBorder"] = "muppet_sprite_button_noBorder",
        ["noBorder_mod"] = "muppet_sprite_button_noBorder_mod",
        ["noBorder_smallText"] = "muppet_sprite_button_noBorder_smallText",
        ["noBorder_clickable"] = "muppet_sprite_button_noBorder_clickable",
        ["noBorder_32"] = "muppet_sprite_button_noBorder_32",
        ["noBorder_48"] = "muppet_sprite_button_noBorder_48",
        ["noBorder_64"] = "muppet_sprite_button_noBorder_64",
        ["frameCloseButtonClickable"] = "muppet_sprite_button_frameCloseButtonClickable",
        ["frameCloseButtonClickable_mod"] = "muppet_sprite_button_frameCloseButtonClickable_mod",
        ["frameCloseButtonClickable_smallText"] = "muppet_sprite_button_frameCloseButtonClickable_smallText",
        ["frameCloseButtonClickable_clickable"] = "muppet_sprite_button_frameCloseButtonClickable_clickable",
        ["frameCloseButtonClickable_32"] = "muppet_sprite_button_frameCloseButtonClickable_32",
        ["frameCloseButtonClickable_48"] = "muppet_sprite_button_frameCloseButtonClickable_48",
        ["frameCloseButtonClickable_64"] = "muppet_sprite_button_frameCloseButtonClickable_64"
    },
    button = {
        small = {
            ["plain"] = "muppet_button_text_small",
            ["paddingSides"] = "muppet_button_text_small_paddingSides",
            ["paddingNone"] = "muppet_button_text_small_paddingNone",
            ["paddingTight"] = "muppet_button_text_small_paddingTight",
            ["frame"] = "muppet_button_text_small_frame",
            ["frame_paddingSides"] = "muppet_button_text_small_frame_paddingSides",
            ["frame_paddingNone"] = "muppet_button_text_small_frame_paddingNone",
            ["frame_paddingTight"] = "muppet_button_text_small_frame_paddingTight",
            ["noBorder"] = "muppet_button_text_small_noBorder",
            ["noBorder_paddingSides"] = "muppet_button_text_small_noBorder_paddingSides",
            ["noBorder_paddingNone"] = "muppet_button_text_small_noBorder_paddingNone",
            ["noBorder_paddingTight"] = "muppet_button_text_small_noBorder_paddingTight",
            ["semibold"] = "muppet_button_text_small_semibold",
            ["semibold_paddingSides"] = "muppet_button_text_small_semibold_paddingSides",
            ["semibold_paddingNone"] = "muppet_button_text_small_semibold_paddingNone",
            ["semibold_paddingTight"] = "muppet_button_text_small_semibold_paddingTight",
            ["semibold_frame"] = "muppet_button_text_small_semibold_frame",
            ["semibold_frame_paddingSides"] = "muppet_button_text_small_semibold_frame_paddingSides",
            ["semibold_frame_paddingNone"] = "muppet_button_text_small_semibold_frame_paddingNone",
            ["semibold_frame_paddingTight"] = "muppet_button_text_small_semibold_frame_paddingTight",
            ["semibold_noBorder"] = "muppet_button_text_small_semibold_noBorder",
            ["semibold_noBorder_paddingSides"] = "muppet_button_text_small_semibold_noBorder_paddingSides",
            ["semibold_noBorder_paddingNone"] = "muppet_button_text_small_semibold_noBorder_paddingNone",
            ["semibold_noBorder_paddingTight"] = "muppet_button_text_small_semibold_noBorder_paddingTight",
            ["bold"] = "muppet_button_text_small_bold",
            ["bold_paddingSides"] = "muppet_button_text_small_bold_paddingSides",
            ["bold_paddingNone"] = "muppet_button_text_small_bold_paddingNone",
            ["bold_paddingTight"] = "muppet_button_text_small_bold_paddingTight",
            ["bold_frame"] = "muppet_button_text_small_bold_frame",
            ["bold_frame_paddingSides"] = "muppet_button_text_small_bold_frame_paddingSides",
            ["bold_frame_paddingNone"] = "muppet_button_text_small_bold_frame_paddingNone",
            ["bold_frame_paddingTight"] = "muppet_button_text_small_bold_frame_paddingTight",
            ["bold_noBorder"] = "muppet_button_text_small_bold_noBorder",
            ["bold_noBorder_paddingSides"] = "muppet_button_text_small_bold_noBorder_paddingSides",
            ["bold_noBorder_paddingNone"] = "muppet_button_text_small_bold_noBorder_paddingNone",
            ["bold_noBorder_paddingTight"] = "muppet_button_text_small_bold_noBorder_paddingTight"
        },
        medium = {
            ["plain"] = "muppet_button_text_medium",
            ["paddingSides"] = "muppet_button_text_medium_paddingSides",
            ["paddingNone"] = "muppet_button_text_medium_paddingNone",
            ["paddingTight"] = "muppet_button_text_medium_paddingTight",
            ["frame"] = "muppet_button_text_medium_frame",
            ["frame_paddingSides"] = "muppet_button_text_medium_frame_paddingSides",
            ["frame_paddingNone"] = "muppet_button_text_medium_frame_paddingNone",
            ["frame_paddingTight"] = "muppet_button_text_medium_frame_paddingTight",
            ["noBorder"] = "muppet_button_text_medium_noBorder",
            ["noBorder_paddingSides"] = "muppet_button_text_medium_noBorder_paddingSides",
            ["noBorder_paddingNone"] = "muppet_button_text_medium_noBorder_paddingNone",
            ["noBorder_paddingTight"] = "muppet_button_text_medium_noBorder_paddingTight",
            ["semibold"] = "muppet_button_text_medium_semibold",
            ["semibold_paddingSides"] = "muppet_button_text_medium_semibold_paddingSides",
            ["semibold_paddingNone"] = "muppet_button_text_medium_semibold_paddingNone",
            ["semibold_paddingTight"] = "muppet_button_text_medium_semibold_paddingTight",
            ["semibold_frame"] = "muppet_button_text_medium_semibold_frame",
            ["semibold_frame_paddingSides"] = "muppet_button_text_medium_semibold_frame_paddingSides",
            ["semibold_frame_paddingNone"] = "muppet_button_text_medium_semibold_frame_paddingNone",
            ["semibold_frame_paddingTight"] = "muppet_button_text_medium_semibold_frame_paddingTight",
            ["semibold_noBorder"] = "muppet_button_text_medium_semibold_noBorder",
            ["semibold_noBorder_paddingSides"] = "muppet_button_text_medium_semibold_noBorder_paddingSides",
            ["semibold_noBorder_paddingNone"] = "muppet_button_text_medium_semibold_noBorder_paddingNone",
            ["semibold_noBorder_paddingTight"] = "muppet_button_text_medium_semibold_noBorder_paddingTight",
            ["bold"] = "muppet_button_text_medium_bold",
            ["bold_paddingSides"] = "muppet_button_text_medium_bold_paddingSides",
            ["bold_paddingNone"] = "muppet_button_text_medium_bold_paddingNone",
            ["bold_paddingTight"] = "muppet_button_text_medium_bold_paddingTight",
            ["bold_frame"] = "muppet_button_text_medium_bold_frame",
            ["bold_frame_paddingSides"] = "muppet_button_text_medium_bold_frame_paddingSides",
            ["bold_frame_paddingNone"] = "muppet_button_text_medium_bold_frame_paddingNone",
            ["bold_frame_paddingTight"] = "muppet_button_text_medium_bold_frame_paddingTight",
            ["bold_noBorder"] = "muppet_button_text_medium_bold_noBorder",
            ["bold_noBorder_paddingSides"] = "muppet_button_text_medium_bold_noBorder_paddingSides",
            ["bold_noBorder_paddingNone"] = "muppet_button_text_medium_bold_noBorder_paddingNone",
            ["bold_noBorder_paddingTight"] = "muppet_button_text_medium_bold_noBorder_paddingTight"
        },
        large = {
            ["plain"] = "muppet_button_text_large",
            ["paddingSides"] = "muppet_button_text_large_paddingSides",
            ["paddingNone"] = "muppet_button_text_large_paddingNone",
            ["paddingTight"] = "muppet_button_text_large_paddingTight",
            ["frame"] = "muppet_button_text_large_frame",
            ["frame_paddingSides"] = "muppet_button_text_large_frame_paddingSides",
            ["frame_paddingNone"] = "muppet_button_text_large_frame_paddingNone",
            ["frame_paddingTight"] = "muppet_button_text_large_frame_paddingTight",
            ["noBorder"] = "muppet_button_text_large_noBorder",
            ["noBorder_paddingSides"] = "muppet_button_text_large_noBorder_paddingSides",
            ["noBorder_paddingNone"] = "muppet_button_text_large_noBorder_paddingNone",
            ["noBorder_paddingTight"] = "muppet_button_text_large_noBorder_paddingTight",
            ["semibold"] = "muppet_button_text_large_semibold",
            ["semibold_paddingSides"] = "muppet_button_text_large_semibold_paddingSides",
            ["semibold_paddingNone"] = "muppet_button_text_large_semibold_paddingNone",
            ["semibold_paddingTight"] = "muppet_button_text_large_semibold_paddingTight",
            ["semibold_frame"] = "muppet_button_text_large_semibold_frame",
            ["semibold_frame_paddingSides"] = "muppet_button_text_large_semibold_frame_paddingSides",
            ["semibold_frame_paddingNone"] = "muppet_button_text_large_semibold_frame_paddingNone",
            ["semibold_frame_paddingTight"] = "muppet_button_text_large_semibold_frame_paddingTight",
            ["semibold_noBorder"] = "muppet_button_text_large_semibold_noBorder",
            ["semibold_noBorder_paddingSides"] = "muppet_button_text_large_semibold_noBorder_paddingSides",
            ["semibold_noBorder_paddingNone"] = "muppet_button_text_large_semibold_noBorder_paddingNone",
            ["semibold_noBorder_paddingTight"] = "muppet_button_text_large_semibold_noBorder_paddingTight",
            ["bold"] = "muppet_button_text_large_bold",
            ["bold_paddingSides"] = "muppet_button_text_large_bold_paddingSides",
            ["bold_paddingNone"] = "muppet_button_text_large_bold_paddingNone",
            ["bold_paddingTight"] = "muppet_button_text_large_bold_paddingTight",
            ["bold_frame"] = "muppet_button_text_large_bold_frame",
            ["bold_frame_paddingSides"] = "muppet_button_text_large_bold_frame_paddingSides",
            ["bold_frame_paddingNone"] = "muppet_button_text_large_bold_frame_paddingNone",
            ["bold_frame_paddingTight"] = "muppet_button_text_large_bold_frame_paddingTight",
            ["bold_noBorder"] = "muppet_button_text_large_bold_noBorder",
            ["bold_noBorder_paddingSides"] = "muppet_button_text_large_bold_noBorder_paddingSides",
            ["bold_noBorder_paddingNone"] = "muppet_button_text_large_bold_noBorder_paddingNone",
            ["bold_noBorder_paddingTight"] = "muppet_button_text_large_bold_noBorder_paddingTight"
        }
    },
    label = {
        text = {
            small = {
                ["plain"] = "muppet_label_text_small",
                ["paddingBR"] = "muppet_label_text_small_paddingBR",
                ["paddingSides"] = "muppet_label_text_small_paddingSides",
                ["marginTL"] = "muppet_label_text_small_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_text_small_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_text_small_marginTL_paddingSides",
                ["semibold"] = "muppet_label_text_small_semibold",
                ["semibold_paddingBR"] = "muppet_label_text_small_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_text_small_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_text_small_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_text_small_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_text_small_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_text_small_bold",
                ["bold_paddingBR"] = "muppet_label_text_small_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_text_small_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_text_small_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_text_small_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_text_small_bold_marginTL_paddingSides"
            },
            medium = {
                ["plain"] = "muppet_label_text_medium",
                ["paddingBR"] = "muppet_label_text_medium_paddingBR",
                ["paddingSides"] = "muppet_label_text_medium_paddingSides",
                ["marginTL"] = "muppet_label_text_medium_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_text_medium_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_text_medium_marginTL_paddingSides",
                ["semibold"] = "muppet_label_text_medium_semibold",
                ["semibold_paddingBR"] = "muppet_label_text_medium_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_text_medium_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_text_medium_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_text_medium_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_text_medium_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_text_medium_bold",
                ["bold_paddingBR"] = "muppet_label_text_medium_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_text_medium_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_text_medium_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_text_medium_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_text_medium_bold_marginTL_paddingSides"
            },
            large = {
                ["plain"] = "muppet_label_text_large",
                ["paddingBR"] = "muppet_label_text_large_paddingBR",
                ["paddingSides"] = "muppet_label_text_large_paddingSides",
                ["marginTL"] = "muppet_label_text_large_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_text_large_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_text_large_marginTL_paddingSides",
                ["semibold"] = "muppet_label_text_large_semibold",
                ["semibold_paddingBR"] = "muppet_label_text_large_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_text_large_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_text_large_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_text_large_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_text_large_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_text_large_bold",
                ["bold_paddingBR"] = "muppet_label_text_large_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_text_large_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_text_large_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_text_large_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_text_large_bold_marginTL_paddingSides"
            }
        },
        heading = {
            small = {
                ["plain"] = "muppet_label_heading_small",
                ["paddingBR"] = "muppet_label_heading_small_paddingBR",
                ["paddingSides"] = "muppet_label_heading_small_paddingSides",
                ["marginTL"] = "muppet_label_heading_small_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_heading_small_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_heading_small_marginTL_paddingSides",
                ["semibold"] = "muppet_label_heading_small_semibold",
                ["semibold_paddingBR"] = "muppet_label_heading_small_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_heading_small_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_heading_small_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_heading_small_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_heading_small_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_heading_small_bold",
                ["bold_paddingBR"] = "muppet_label_heading_small_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_heading_small_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_heading_small_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_heading_small_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_heading_small_bold_marginTL_paddingSides"
            },
            medium = {
                ["plain"] = "muppet_label_heading_medium",
                ["paddingBR"] = "muppet_label_heading_medium_paddingBR",
                ["paddingSides"] = "muppet_label_heading_medium_paddingSides",
                ["marginTL"] = "muppet_label_heading_medium_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_heading_medium_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_heading_medium_marginTL_paddingSides",
                ["semibold"] = "muppet_label_heading_medium_semibold",
                ["semibold_paddingBR"] = "muppet_label_heading_medium_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_heading_medium_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_heading_medium_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_heading_medium_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_heading_medium_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_heading_medium_bold",
                ["bold_paddingBR"] = "muppet_label_heading_medium_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_heading_medium_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_heading_medium_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_heading_medium_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_heading_medium_bold_marginTL_paddingSides"
            },
            large = {
                ["plain"] = "muppet_label_heading_large",
                ["paddingBR"] = "muppet_label_heading_large_paddingBR",
                ["paddingSides"] = "muppet_label_heading_large_paddingSides",
                ["marginTL"] = "muppet_label_heading_large_marginTL",
                ["marginTL_paddingBR"] = "muppet_label_heading_large_marginTL_paddingBR",
                ["marginTL_paddingSides"] = "muppet_label_heading_large_marginTL_paddingSides",
                ["semibold"] = "muppet_label_heading_large_semibold",
                ["semibold_paddingBR"] = "muppet_label_heading_large_semibold_paddingBR",
                ["semibold_paddingSides"] = "muppet_label_heading_large_semibold_paddingSides",
                ["semibold_marginTL"] = "muppet_label_heading_large_semibold_marginTL",
                ["semibold_marginTL_paddingBR"] = "muppet_label_heading_large_semibold_marginTL_paddingBR",
                ["semibold_marginTL_paddingSides"] = "muppet_label_heading_large_semibold_marginTL_paddingSides",
                ["bold"] = "muppet_label_heading_large_bold",
                ["bold_paddingBR"] = "muppet_label_heading_large_bold_paddingBR",
                ["bold_paddingSides"] = "muppet_label_heading_large_bold_paddingSides",
                ["bold_marginTL"] = "muppet_label_heading_large_bold_marginTL",
                ["bold_marginTL_paddingBR"] = "muppet_label_heading_large_bold_marginTL_paddingBR",
                ["bold_marginTL_paddingSides"] = "muppet_label_heading_large_bold_marginTL_paddingSides"
            }
        }
    },
    textbox = {
        ["plain"] = "muppet_textbox",
        ["paddingBR"] = "muppet_textbox_paddingBR",
        ["marginTL"] = "muppet_textbox_marginTL",
        ["marginTL_paddingBR"] = "muppet_textbox_marginTL_paddingBR"
    }
}

---@class UtilityGuiStyle_MuppetFonts
StyleData.MuppetFonts = {
    muppet_small_1_1_0 = "muppet_small_1_1_0",
    muppet_small_semibold_1_1_0 = "muppet_small_semibold_1_1_0",
    muppet_small_bold_1_1_0 = "muppet_small_bold_1_1_0",
    muppet_medium_1_1_0 = "muppet_medium_1_1_0",
    muppet_medium_semibold_1_1_0 = "muppet_medium_semibold_1_1_0",
    muppet_medium_bold_1_1_0 = "muppet_medium_bold_1_1_0",
    muppet_large_1_1_0 = "muppet_large_1_1_0",
    muppet_large_semibold_1_1_0 = "muppet_large_semibold_1_1_0",
    muppet_large_bold_1_1_0 = "muppet_large_bold_1_1_0"
}

return StyleData
