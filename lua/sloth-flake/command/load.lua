local Dep = require 'sloth-flake.dep'
local utils = require 'sloth-flake.utils'

return {
  complete = function(line)
    local previous_deps = vim.iter(line.args):enumerate():map(function(i, arg)
      if i < 3 or i > line.arg_idx then return end
      return arg.arg
    end):totable()

    local prefix = line.args[line.arg_idx].arg
    return vim.iter(Dep.all()):filter(function(name, dep)
      return vim.startswith(name, prefix) and not dep.is_loaded
          and not vim.list_contains(previous_deps, name)
    end):map(function(name)
      return name
    end):totable()
  end,

  cmd = function(plugins)
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
  end,
}
