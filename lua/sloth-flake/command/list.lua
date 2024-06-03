local Dep = require 'sloth-flake.dep'
local utils = require 'sloth-flake.utils'

return function(args)
  local filter = args[1] or "all"
  local deps = vim.iter(Dep.all()):map(function(_, dep)
    return dep.name
  end)
  if filter == "all" then
    -- Nothing to do
  elseif filter == "loaded" then
    deps = deps:filter(function(dep)
      return Dep.get(dep).is_loaded
    end)
  elseif filter == "notloaded" then
    deps = deps:filter(function(dep)
      return not Dep.get(dep).is_loaded
    end)
  else
    utils.error([[No Sloth list filter "%s".]], cmd)
    utils.error("Filters are: all, loaded, notloaded")
    return
  end
  deps = deps:totable()
  table.sort(deps)
  for _, dep in ipairs(deps) do
    print(string.format("- %s", dep))
  end
end
