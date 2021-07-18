---
--  Account module.
--
--  @module     lupidary.authn
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local schema = '{username}:{role}:{sha256sum}'

local attrs = {}
local matcher = '^' .. string.gsub(schema, '{(%w+)}', function (attr)
    table.insert(attrs, attr)
    return '(%w+)'
end) .. '$'

local mt = {}

function mt:authn(username, hashed_password)
    for _, acct in ipairs(self.accounts) do
        if acct.username == username then
            if acct.sha256sum == hashed_password then
                return acct.role
            end
            return false, 'Password Mismatch'
        end
    end
    return false, 'User Not Found'
end

function _M.load(path)
    local o = {}

    local accounts = {}
    for l in io.lines(path) do
        local acct = table.pack(string.match(l, matcher))
        for i, v in ipairs(attrs) do
            acct[v] = acct[i]
        end
        table.insert(accounts, acct)
    end

    o.accounts = setmetatable(accounts, {
        __tostring = function (self)
            local partials = {}
            for _, acct in ipairs(self) do
                table.insert(partials, table.concat(acct, ':'))
            end
            return '{\n  ' .. table.concat(partials, ',\n  ') .. '\n}'
        end
    })

    setmetatable(o, {__index = mt})
    return o
end

return _M
