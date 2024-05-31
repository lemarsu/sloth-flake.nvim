local Dep = require 'sloth-flake.dep'
local utils = require 'sloth-flake.utils'

return function(plugins)
  if #plugins == 0 then
    utils.error("You should at least give a plugin to load!")
    return
  end
  for _, plugin in ipairs(plugins) do
    local dep = Dep.get(plugin)
    if dep ~= nil then
      dep:load()
    end
  end
end
