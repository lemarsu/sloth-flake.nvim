local Dep = require 'sloth-flake.dep'
local utils = require 'sloth-flake.utils'

local filters = {
  all = {
    filter = function(iter)
      -- Nothing to do
      return iter
    end
  },
  loaded = {
    filter = function(iter)
      return iter:filter(function(dep)
        return Dep.get(dep).is_loaded
      end)
    end
  },
  notloaded = {
    filter = function(iter)
      return iter:filter(function(dep)
        return not Dep.get(dep).is_loaded
      end)
    end
  },
}

return {
  complete = function(line)
    if line.arg_idx == 3 then
      local prefix = line.args[3].arg
      return vim.iter(vim.tbl_keys(filters)):filter(function(name)
        return vim.startswith(name, prefix)
      end):totable()
    end
  end,

  cmd = function(args)
    local filter_name = args[1] or "all"
    local filter = filters[filter_name]
    if not filter then
      utils.error([[No Sloth list filter "%s".]], cmd)
      utils.error("Filters are: %s", vim.iter(vim.tbl_keys(filters)):join(', '))
      return
    end

    local deps = vim.iter(Dep.all()):map(function(_, dep)
      return dep.name
    end)
    deps = filter.filter(deps):totable()
    table.sort(deps)
    for _, dep in ipairs(deps) do
      print(string.format("- %s", dep))
    end
  end,
}
