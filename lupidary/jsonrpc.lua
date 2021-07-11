---
--  JSON-RPC module.
--
--  @module     lupidary.jsonrpc
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local json = require('json')

local mt = {}
mt.__index = mt

local mt_req = {}
mt_req.__index = mt_req

function mt_req:response(data)
    local o = {
        jsonrpc = '2.0',
        id = self.data_.id,
    }
    if data['error'] then
        o['error'] = data['error']
    elseif data.result then
        o.result = data.result
    else
        error('Response must have result or error field')
    end

    self.parent_.so_:send(json.encode(o))
end

function mt:receive()
    local o = {
        parent_ = self,
    }

    local data = nil
    local buffer = (self.carry_over_ or '')
    while true do
        local nest = 0
        for i = 1, #buffer do
            local c = string.byte(buffer, i)
            if c == 123 then -- '{'
                nest = nest + 1
            elseif c == 125 then -- '}'
                nest = nest - 1

                if nest == 0 then
                    self.carry_over_ = string.sub(buffer, i + 1)
                    data = json.decode(string.sub(buffer, 1, i))
                    break
                end
            end
        end
        if data then
            break
        end

        local err, chunk = select(2, self.so_:receive('*a'))
        if err ~= 'timeout' then
            error(err)
        end
        buffer = buffer .. chunk
    end

    if data.jsonrpc ~= '2.0' then
        error('Version not supported (expected 2.0 but got ' .. data.jsonrpc ..')')
    end

    o.method = data.method
    o.params = data.params
    o.id = data.id
    o.data_ = data

    setmetatable(o, {__index = mt_req})
    return o
end

function mt:send(data)
    self.so_:send(json.encode({
        jsonrpc = '2.0',
        method = data.method or error('Request must have method field'),
        params = data.params,
        id = data.id,
    }))
end

function _M.wrap(so)
    local o = {
        so_ = so,
    }

    setmetatable(o, {__mode = 'v', __index = mt})
    return o
end

return _M
