--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:33
-- 系统默认配置
--
return {
    enabled_admin = true,
    enabled_policies = { "RANGE", "SUFFIX", "COMPOSITE", "MODULO", "REGEX" },
    enabled_mappers = { "HEADER", "URI_ARGS", "IP", "URI" },
    default_paths = {
        "E:/work/phi/conf/phi.ini", "/home/young/IdeaProjects/phi/conf/phi.ini", "/home/phi/conf/application.ini"
    },
    application_context_conf = {
        "E:/work/phi/phi/config/application.ini", "/home/young/IdeaProjects/phi/phi/config/application.ini", "/home/phi/phi/config/application.ini"
    }
}