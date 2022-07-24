---@meta
---Lua serializer and pretty printer.\
---Author: [Paul Kulchenko](mailto:paul@kulchenko.com)\
---https://github.com/pkulchenko/serpent
---```lua
---local serpent = require("serpent")
---local a = {1, nil, 3, x=1, ['true'] = 2, [not true]=3}
---a[a] = a -- self-reference with a table as key and value
---
---print(serpent.dump(a)) -- full serialization
---print(serpent.line(a)) -- single line, no self-ref section
---print(serpent.block(a)) -- multi-line indented, no self-ref section
---
---local fun, err = loadstring(serpent.dump(a))
---if err then error(err) end
---local copy = fun()
---
---
---local ok, copy = serpent.load(serpent.dump(a))
---print(ok and copy[3] == a[3])
---```
---\
---Note that line and block functions return pretty-printed data structures and if you want to deserialize them,
---you need to add return before running them through loadstring. For example:
---```lua
---loadstring('return '..require('mobdebug').line("foo"))() == "foo"
---```
---\
---If a table or a userdata value has `__tostring` or `__serialize` method, the method will be used to serialize the value.\
---If `__serialize` method is present, it will be called with the value as a parameter. if `__serialize` method is not present, but `__tostring` is,
---then tostring will be called with the value as a parameter. In both cases, the result will be serialized, so `__serialize` method can return a table,
---that will be serialized and replace the original value.
---
---Limitations:\
---Doesn't handle userdata (except filehandles in io.* table).\
---Threads, function upvalues/environments, and metatables are not serialized.
---@class serpent
serpent = {}

-- multi-line indented pretty printing, no self-ref section; sets indent, sortkeys, and comment options.
---@param T any
---@param options? serpent.options
---@return string
function serpent.block(T, options)
end

---Single line pretty printing, no self-ref section; sets sortkeys and comment options;
---@param T any
---@param options? serpent.options
---@return string
function serpent.line(T, options)
end

---Full serialization; sets name, compact and sparse options
---@param T any
---@param options? serpent.options
---@return string
function serpent.dump(T, options)
end

---loads serialized fragment; you need to pass {safe = false} as the second value if you want to turn safety checks off.\
---Similar to pcall and loadstring calls, load returns status as the first value and the result or the error message as the second value.
---@param str string
---@param options? serpent.load_options
---@return boolean, any
function serpent.load(str, options)
end

---@class serpent.load_options
---@field safe boolean default: true

---These options can be provided as a second parameter to Serpent functions.
---
---Serpent functions set these options to different default values:\
--- - `serpent.dump(T)` sets `compact = true` and `sparse = true`;\
--- - `serpent.line(T)` sets `sortkeys = true` and `comment = true`;\
--- - `serpent.block(T)` sets `sortkeys = true` and `comment = true` and `indent = ' '`.
---@class serpent.options
---@field safe boolean enable safety checks when using `serpent.load`. default: true
---@field indent string triggers long multi-line output.
---@field comment boolean provide stringified value in a comment (up to `maxelevel` of depth).
---@field sortkeys boolean|serpent.sort_function
---@field sparse boolean force sparese encoding (no nil filling based on #t).
---@field compact boolean remove spaces.
---@field fatal boolean raise fatal error on non-serilializable values.
---@field fixradix boolean change radic character set depenending on locale to decimal dot.
---@field nocode boolean disable bytecode serialization for easy comparison.
---@field nohuge boolean disable checking numbers against undefined and huge values.
---@field maxlevel number specify max level up to which to expand nested tables.
---@field maxnum number specify max number of elemmets in a table.
---@field maxlength number specify max length for all table elements.
---@field metatostring boolean use __tostring metatamethod when serializing tables; set to false to disable and serialize the table as is.
---@field numformat string specify format for numeric values as shortest possible round-trippable double.\
---Use "%.16g" for better readability and "%.17g" to preserve floating point precision. default: "%.17g"
---@field valignore {[string]: true} allows to specify a list of values to ignore (as keys).
---@field keyallow {[string]: true} allows to specify the list of keys to be serialized. Any keys not in this list are not included in final output (as keys).
---@field keyignore {[string]: true} allows to specity the list of keys to ignore in serialization.
---@field valtypeignore {[string]: true} allows to specify a list of value types to ignore (as keys).
---@field custom serpent.formater
---@field name string triggers full serialization with self-ref section.

---A custom sort function can be provided to sort the contents of tables. The function takes 2 parameters, the first being the table (a list) with the keys,
---the second the original table. It should modify the first table in-place, and return nothing.\
---For example, the following call will apply a sort function identical to the standard sort, except that it will not distinguish between lower- and uppercase.
---```lua
---local mysort  = function(array_of_keys, original_table)
---  local maxn, to = 12, { number = "a", string = "b" }
---  local function padnum(d) return ("%0" .. maxn .. "d"):format(d) end
---
---  local sort = function(a, b)
---    return ((array_of_keys[a] and 0 or to[type(a)] or "z") .. (tostring(a):gsub("%d+", padnum))):upper()
---        < ((array_of_keys[b] and 0 or to[type(b)] or "z") .. (tostring(b):gsub("%d+", padnum))):upper()
---  end
---  table.sort(array_of_keys, sort)
---end
---local content = { some = 1, input = 2, To = 3, serialize = 4 }
---local result  = serpent.line(content, { sortkeys = mysort })
---print(result) -- {input = 2, serialize = 4, some = 1, To = 3}
---```
---@alias serpent.sort_function fun(array_of_keys: string[], original_table: table)

---Serpent supports a way to provide a custom formatter that allows to fully customize the output. The formatter takes five values:
---
---  `tag` -- the name of the current element with '=' or an empty string in case of array index,\
---  `head` -- an opening table bracket { and associated indentation and newline (if any),\
---  `body` -- table elements concatenated into a string using commas and indentation/newlines (if any),\
---  `tail` -- a closing table bracket } and associated indentation and newline (if any), and\
---  `level` -- the current level.
---
---For example, the following call will apply `Foo{bar} notation to its output (used by Metalua to display ASTs):
---```lua
---local function formatter(tag, head, body, tail)
---local out = head .. body .. tail
---  if tag:find("^lineinfo") then
---    out = out:gsub("\n%s+", "") -- collapse lineinfo to one line
---  elseif tag == "" then
---    body = body:gsub("%s*lineinfo = [^\n]+", "")
---    local _, _, atag = body:find('tag = "(%w+)"%s*$')
---    if atag then
---      out = "`" .. atag .. head .. body:gsub('%s*tag = "%w+"%s*$', "") .. tail
---      out = out:gsub("\n%s+", ""):gsub(",}", "}")
---    else out = head .. body .. tail end
---  end
---  return tag .. out
---end
---
---print(serpent.block(ast, { comment = false, custom = formatter }))
---```
---@alias serpent.formater fun(tag: string, head: string, body: string, tail: string, level: number)
