---
--  Utility module.
--
--  @module     lupidary.util
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {}
_M.__index = _M

local insert = table.insert
local gsub = string.gsub

function _M.flatten(...)
    local t_ = {}

    local function flatten_(t)
        for _, v in ipairs(t) do
            if type(v) == 'table' then
                flatten_(v)
            else
                insert(t_, v)
            end
        end
    end

    flatten_{...}
    return t_
end

function _M.indexof(t, val)
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    for k, v in pairs(t) do
        if v == val then
            return k
        end
    end
end

function _M.trim(s)
    return (gsub(s, '^%s*(.-)%s*$', '%1'))
end

return _M
