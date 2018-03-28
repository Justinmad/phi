local lor = require("lor.index")
local app = lor()
local router = require("api.router")

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
