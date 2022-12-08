-- Make our own small, medium and large spit stream and fire. So that we can hard code the sounds in to the fire creation rather than as part of the stream; Thus mitigating the sound issue when the stream is created too far from the player, yet it lands near them.
-- This assumes the old stream and fire prototypes still exist, even if in theory another mod could have changed them before us. Some of the referencing is also hard coded to vanilla data structure. if it hits issues it will need to be made more dynamic.

local TableUtils = require("utility.helper-utils.table-utils")

-- List the new base name to the old stream and fire.
local spitsToCreate = {
    {
        newNameBase = "muppet_streamer-small_spit",
        oldSpitName = "acid-stream-spitter-small",
        oldFireName = "acid-splash-fire-spitter-small"
    },
    {
        newNameBase = "muppet_streamer-medium_spit",
        oldSpitName = "acid-stream-worm-medium",
        oldFireName = "acid-splash-fire-worm-medium"
    },
    {
        newNameBase = "muppet_streamer-large_spit",
        oldSpitName = "acid-stream-worm-behemoth",
        oldFireName = "acid-splash-fire-worm-behemoth"
    }
}

-- For each stream and fire pair we want to change do it.
for _, details in pairs(spitsToCreate) do
    local spitStream = TableUtils.DeepCopy(data.raw["stream"][details.oldSpitName]) --[[@as Prototype.FluidStream]]
    spitStream.name = details.newNameBase .. "-stream"
    spitStream.working_sound = nil -- Remove the horrible in-air noise as it can drown out our landing noises and doesn't stack nicely.
    local spitStream_targetEffects = spitStream.initial_action[1].action_delivery.target_effects --[[@as TriggerEffectItem|TriggerEffectItem[] ]]
    local spitStreamImpactSound_PlaySoundTriggerEffectItems
    -- Find the first sound, grab a reference to the table and then remove it from the stream. We will add it to the fire later.
    for i, targetEffect in pairs(spitStream_targetEffects) do
        if targetEffect.type == "play-sound" then
            ---@cast targetEffect PlaySoundTriggerEffectItem
            spitStreamImpactSound_PlaySoundTriggerEffectItems = targetEffect
            table.remove(spitStream_targetEffects, i)
            break
        end
    end
    -- Then update the fire name we will create.
    for i, targetEffect in pairs(spitStream_targetEffects) do
        if targetEffect.type == "create-fire" then
            ---@cast targetEffect CreateFireTriggerEffectItem
            if targetEffect.entity_name == details.oldFireName then
                targetEffect.entity_name = details.newNameBase .. "-fire"
                break
            end
        end
    end

    -- Make the sounds twice as loud so they are actually hear-able.
    ---@cast spitStreamImpactSound_PlaySoundTriggerEffectItems PlaySoundTriggerEffectItem
    for _, soundEffectItem in pairs(spitStreamImpactSound_PlaySoundTriggerEffectItems.sound) do
        soundEffectItem.volume = soundEffectItem.volume * 2
    end

    local spitFire = TableUtils.DeepCopy(data.raw["fire"][details.oldFireName])
    spitFire.name = details.newNameBase .. "-fire"
    local newCreatedEffect = { type = "direct",
        action_delivery =
        {
            type = "instant",
            target_effects =
            {
                spitStreamImpactSound_PlaySoundTriggerEffectItems
            }
        }
    }
    spitFire.created_effect = TableUtils.TableMergeCopies({ spitFire.created_effect or {}, newCreatedEffect })

    data:extend({ spitStream, spitFire })
end
