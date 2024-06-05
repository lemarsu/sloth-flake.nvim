local Dep = require 'sloth-flake.dep'
local utils = require 'sloth-flake.utils'

local function yesno(value)
  return value and "Yes" or "No"
end

local function list(items)
  if items == nil or #items == 0 then
    return "None"
  end
  return vim.iter(items):join(', ')
end

local function describe(dep)
  utils.info('Name:         %s', dep.name)
  utils.info('Is loaded:    %s', yesno(dep.is_loaded))
  utils.info('Is lazy:      %s', yesno(dep.is_lazy))
  utils.info('Has init:     %s', yesno(dep.init))
  utils.info('Has config:   %s', yesno(dep.config))
  utils.info('Dependencies: %s', list(dep.dependency_names))
  utils.info('Filetypes:    %s', list(dep.ft))
  utils.info('Commands:     %s', list(dep.cmd))
  if dep.events == nil then
    utils.info('Events:       None')
  else
    utils.info('Events:')
    for _, event in ipairs(dep.events) do
      for _, name in ipairs(event.name) do
        for _, pattern in ipairs(event.pattern) do
          utils.info(' - %s %s', name, pattern)
        end
      end
    end
  end
  if dep.keymaps == nil then
    utils.info('Keymaps:      None')
  else
    utils.info('Keymaps:')
    for _, keymap in ipairs(dep.keymaps) do
      for _, mode in ipairs(keymap.mode) do
        for _, mapping in ipairs(keymap.mapping) do
          utils.info(' - %s %s', mode, mapping)
        end
      end
    end
  end
end

return {
  complete = function(line)
    if line.arg_idx == 3 then
      local prefix = line.args[line.arg_idx].arg
      return vim.iter(Dep.all()):map(function(name)
        return name
      end):filter(function(name)
        return vim.startswith(name, prefix)
      end):totable()
    end
  end,

  cmd = function(plugins)
    if #plugins == 0 then
      utils.error("You should at least give a plugin to describe!")
      return
    end
    local plugin = plugins[1]
    local dep = Dep.get(plugin)
    if dep == nil then
      return utils.error([[Unknown plugin "%s"]], plugin)
    end
    describe(dep)
  end,
}
