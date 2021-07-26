---
--  Session module.
--
--  @module     lupidary.session
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

math.randomseed(os.time())

local alnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

local sessions = {}

function _M.find_by_id(id)
    for _, v in ipairs(sessions) do
        if v.id == id then
            return v
        end
    end
end

function _M.generate(length)
    length = length or 20
    local key = ''
    for _ = 1, length do
        key = key .. string.char(string.byte(alnum, math.random(1, #alnum)))
    end
    return key
end

function _M.add(username, id, data)
    id = id or _M.generate()

    local o = {
        id = id,
        username = username,
        data = data,
    }
    setmetatable(o, {
        __index = table,
        __tostring = function (self)
            return '{' .. self.id .. ',' .. self.username .. '}'
        end,
    })
    table.insert(sessions, o)

    return o
end

function _M.delete(id)
    for i = 1, #sessions do
        if sessions[i].id == id then
            return table.remove(sessions, i)
        end
    end
end

return _M
