---
--  HTTP module.
--
--  @module     lupidary.http
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local lupidary = require('lupidary')
local json = require('json')

local insert, pack, unpack = table.insert, table.pack, table.unpack
local find, match, gsub, gmatch, lower = string.find, string.match, string.gsub, string.gmatch, string.lower
local scgi = lupidary.scgi

local function parse_cookie(str)
    str = str or ''

    local o = {}
    for k, v in gmatch(str, '([%w_-]*)=([%w_-]*);*') do
        o[k] = v
    end
    setmetatable(o, {__index = o})
    return o
end

local function request(environ)
    local content_length = tonumber(environ['CONTENT_LENGTH']) or 0
    local o = {
        content = environ['scgi.input']:receive(content_length) or '',
        cookie = parse_cookie(environ['HTTP_COOKIE']),
        method = lower(environ['REQUEST_METHOD']),
        params = lupidary.query.parse_qs(environ['QUERY_STRING']),
    }
    o.text = tostring(o.content)

    local content_type = environ['CONTENT_TYPE'] or ''
    if find(content_type, 'application/x-www-form-urlencoded', 1, true) then
        o.media = lupidary.query.parse_qs(o.content)
    end
    if not o.media then
        pcall(function ()
            o.media = json.decode(o.content)
        end)
    end

    setmetatable(o, {__index = o})
    return o
end

local mt = {}
mt.__index = mt

function mt:route(path, handler)
    insert(self.routes, {
        raw_path = path,
        matcher = '^' .. gsub(path, '{[^/]+}', '([^/]*)') .. '$',
        handler = handler,
    })
end

function _M.serve(uri)
    local o = {
        routes = {},
    }

    lupidary.bind(uri, true)
    :onopen(function (so)
        scgi.wrap(so):run(function (environ, start_response)
            local resp = {
                content = 'It works.',
                status_code = '200 OK',
                headers = {
                    ['Content-type'] = 'text/html; charset=utf-8',
                }
            }

            local path = match(environ['REQUEST_URI'], '[^?]+')
            local req = request(environ)
            for _, route in ipairs(o.routes) do
                local args = pack(match(path, route.matcher))
                if #args > 0 then
                    route.handler(req, resp, unpack(args))
                end
            end

            start_response(resp.status_code, resp.headers)
            if type(resp.media) == 'table' then
                return json.encode(resp.media)
            else
                return resp.content
            end
        end)
    end)
    :onerror(function (so, err)
        so:send('Content-type: text/plain\r\nStatus: 500 Internal Server Error\r\n\r\n' .. err)
    end)

    setmetatable(o, {__index = mt})
    return o
end

return _M
