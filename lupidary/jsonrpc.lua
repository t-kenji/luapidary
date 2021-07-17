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

local encode, decode = json.encode, json.decode
local sub, byte = string.sub, string.byte

local mt = {}
mt.__index = mt

local mt_req = {}
mt_req.__index = mt_req

function mt_req:response(data)
    data = data or {}
    local o = {
        jsonrpc = '2.0',
        id = (self.data_ or {}).id,
    }

    local e = data['error']
    if e then
        o['error'] = {
            code = e.code or -32000,
            message = e.message,
            data = e.data,
        }
    elseif data.result then
        o.result = data.result
    else
        error('Response must have result or error field')
    end

    self.parent_.so_:send(encode(o))
end

function mt_req:parse_error(e)
    e = e or {}
    self:response{
        error = {
            code = -32700,
            message = e.message or 'Parse error',
            data = e.data,
        }
    }
end

function mt_req:invalid_request(e)
    e = e or {}
    self:response{
        error = {
            code = -32600,
            message = e.message or 'Invalid Request',
            data = e.data,
        }
    }
end

function mt_req:method_not_found(e)
    e = e or {}
    self:response{
        error = {
            code = -32601,
            message = e.message or 'Method not found',
            data = e.data,
        }
    }
end

function mt_req:invalid_params(e)
    e = e or {}
    self:response{
        error = {
            code = -32602,
            message = e.message or 'Invalid params',
            data = e.data,
        }
    }
end

function mt_req:internal_error(e)
    e = e or {}
    self:response{
        error = {
            code = -32603,
            message = e.message or 'Internal error',
            data = e.data,
        }
    }
end

function mt_req:server_error(e)
    e = e or {}
    self:response{
        error = {
            code = e.code,
            message = e.message or 'Server error',
            data = e.data,
        }
    }
end

function mt:receive()
    local o = {
        parent_ = self,
    }
    setmetatable(o, {__index = mt_req})

    local data = nil
    local buffer = (self.carry_over_ or '')
    while true do
        local nest = 0
        for i = 1, #buffer do
            local c = byte(buffer, i)
            if c == 123 then -- '{'
                nest = nest + 1
            elseif c == 125 then -- '}'
                if nest == 0 then
                    o:parse_error()
                    error('Parse error')
                end
                nest = nest - 1

                if nest == 0 then
                    self.carry_over_ = sub(buffer, i + 1)
                    local ok, err = pcall(function ()
                        data = decode(sub(buffer, 1, i))
                    end)
                    if not ok then
                        o:parse_error()
                        error(err)
                    end
                    break
                end
            end
        end
        if data then
            break
        end

        local err, chunk = select(2, self.so_:receive('*a'))
        if err ~= 'timeout' then
            o:parse_error()
            error(err)
        end
        buffer = buffer .. chunk
    end

    if data.jsonrpc ~= '2.0' then
        o:invalid_request()
        error('Version not supported (expected 2.0 but got ' .. data.jsonrpc ..')')
    end

    o.method = data.method
    o.params = data.params
    o.id = data.id
    o.data_ = data

    return o
end

function mt:send(data)
    self.so_:send(encode({
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
