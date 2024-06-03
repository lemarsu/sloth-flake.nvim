local raw_deps = require 'sloth-flake.dependencies'
local state_machine = require 'sloth-flake.state_machine'

local M = {}

local State = state_machine.build_states {
  'NotLoaded',
  'Shimed',
  'Inited',
  'Imported',
  'Loaded',
}

function M.new(values)
  local self = {
    values = values,
  }
  self.sm = state_machine.build(State, {
    enter = {
      [State.Shimed] = function()
        if self.cmd then
          for _, cmd in ipairs(self.cmd) do
            vim.api.nvim_create_user_command(cmd, self:lazy_load_cmd(cmd), {
              desc = "Sloth-flake placeholder for plugin " .. self.name,
              nargs = '*',
              bang = true,
            })
          end
        end

        if self.ft then
          local group_id = vim.api.nvim_create_augroup(self.augroup_name, {
            clear = true,
          })
          vim.api.nvim_create_autocmd('FileType', {
            group = group_id,
            pattern = self.ft,
            callback = self:lazy_load_ft()
          })
        end
      end,
      [State.Inited] = function()
        for _, dep in ipairs(self.dependencies) do
          dep:init()
        end

        local init = self.values.init or function() end
        init()
      end,
      [State.Imported] = function()
        for _, dep in ipairs(self.dependencies) do
          dep:import()
        end

        if self.is_lazy then
          vim.cmd("packadd " .. self.name)
        end
      end,
      [State.Loaded] = function()
        for _, dep in ipairs(self.dependencies) do
          dep:config()
        end

        local config = self.values.config or function() end
        config()
      end
    },
    exit = {
      [State.Shimed] = function()
        if self.cmd then
          for _, cmd in ipairs(self.cmd) do
            vim.api.nvim_del_user_command(cmd)
          end
        end

        if self.ft then
          vim.api.nvim_del_augroup_by_name(self.augroup_name)
        end
      end,
    },
    events = {
      shim = { from = State.NotLoaded, to = State.Shimed, },
      init = { from = { State.NotLoaded, State.Shimed }, to = State.Inited, },
      import = { from = State.Inited, to = State.Imported, },
      config = { from = State.Imported, to = State.Loaded, },
    },
  })

  return setmetatable(self, {
    __index = function(self, k)
      local fn = M[k]
      if fn then
        return fn
      end
      fn = M['get_' .. k]
      if fn then
        return fn(self)
      end
    end,
    __newindex = function(self, k, v)
      -- Ignore new values
    end
  })
end

function M:get_name()
  return self.values.name
end

function M:get_dependencies()
  local ret = {}
  for _, name in ipairs(self.values.dependencies) do
    local dep = M.get(name)
    if dep ~= nil then
      ret[#ret + 1] = dep
    end
  end
  return ret
end

function M:get_dependency_names()
  local ret = {}
  for _, name in ipairs(self.values.dependencies) do
    ret[#ret + 1] = name
  end
  return ret
end

function M:get_cmd()
  return self.values.cmd
end

function M:get_ft()
  return self.values.ft
end

function M:get_is_lazy()
  return self.values.lazy or false
end

function M:get_state()
  return self.sm.state
end

function M:get_is_imported()
  return self.state >= State.Imported
end

function M:get_is_loaded()
  return self.state >= State.Loaded
end

function M:get_augroup_name()
  return "Sloth-plugin-" .. self.name
end

function M:shim()
  return self.sm:shim()
end

function M:init()
  return self.sm:init()
end

function M:import()
  self:init()
  return self.sm:import()
end

function M:config()
  self:init()
  self:import()
  return self.sm:config()
end

function M:load()
  self:init()
  self:import()
  return self:config()
end

function M:lazy_load_cmd(cmd)
  return function(param)
    self:load()
    local bang = param.bang and '!' or ''
    vim.cmd(cmd .. bang .. ' ' .. param.args)
  end
end

function M:lazy_load_ft()
  return function(param)
    self:load()
    vim.api.nvim_exec_autocmds('FileType', {
      pattern = param.match,
    })
  end
end

local deps = {}
for k, v in pairs(raw_deps) do
  deps[k] = M.new(v)
end

function M.get(name)
  return deps[name]
end

function M.all()
  return deps
end

return M
