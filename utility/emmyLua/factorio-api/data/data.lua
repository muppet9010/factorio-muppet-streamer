---@meta

---All the prototypes will be collected here
---@class data
---@field is_demo boolean This will be overwritten in the c++ based on whether we are in demo or not
---@field raw PrototypeTypes
data = {}

---@param otherdata Prototype[]
function data.extend(self, otherdata) end
