local enabled_mio = require "Phi".configuration.enabled_mio
local Response = require "core.response"
if not enabled_mio then
    return Response.fake({ mio_disabled = true })
end
local lor = require("lor.index")
local app = lor()
local router = require("mio.api.router")

-- routes
app:conf("view enable", true)
app:conf("view engine", "tmpl")
app:conf("view ext", "html")
app:conf("views", "../static")
app:use(router())

-- error handle middleware
app:erroruse(function(err, req, res, next)
    ngx.log(ngx.ERR, err)
    res:status(200):json({
        success = false,
        msg = err
    })
end)

app:run()
