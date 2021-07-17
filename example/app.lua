---
--  Lupidary example application.
--
--  @author t-kenji <protect.2501@gmail.com>

package.path = package.path .. ';../?.lua'

local lupidary = require('lupidary')
lupidary.http = require('lupidary.http')

local serve = lupidary.http.serve

local http = serve('tcp:///tmp/scgi.sock')

http:route('/', function (req, resp)
    resp.status_code = '308 Permanent Redirect'
    resp.headers['Location'] = '/login'
end)

http:route('/users/{who}/status', function (req, resp, who)
    resp.content = string.format([=[
<!DOCTYPE html>
<html lang="ja">
<head>
<title>Status - lupidary example</title>
</head>
<body>
<div>
I am %s!
</div>
</body>
</html>
]=], who)
end)

http:route('/home', function (req, resp)
    resp.content = io.lines('templates/home.html')
    resp.headers['Set-Cookie'] = 'session_id=aaa'
end)

http:route('/login', function (req, resp)
    resp.content = io.lines('templates/login.html')
end)

local jsonrpc = require('lupidary.jsonrpc')

local conns = setmetatable({}, {__mode = 'k'})

lupidary.bind('tcp+listen:///tmp/wstunnel.sock')
:onopen(function (so)
    local rpc = jsonrpc.wrap(so)
    conns[so] = {
        rpc = rpc,
        status = 'connected',
    }
    rpc:send{method = 'preliminary', params = conns[so].status}

    while true do
        local req = rpc:receive()
        req:response{result = 'ok'}
        --req:method_not_found()
        --req:invalid_params()
        --req:internal_error()
        --req:server_error{code = -32001, message = 'Some error occurred', data = 'extra data'}

        for k, v in pairs(conns) do
            if k ~= so then
                v.rpc:send{method = 'onmessage', params = {message = req.method}}
            end
        end
    end
end)
:onclose(function (so)
    conns[so] = nil
end)
:onerror(function (so, err)
    print(err, tostring(so.sock_))
end)

lupidary.run()
