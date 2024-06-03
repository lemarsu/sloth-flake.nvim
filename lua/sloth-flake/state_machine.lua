local M = {}

local stateMeta

local function are_both_states(a, b)
  return a.is_state and b.is_state
end

stateMeta = {
  __tostring = function(v)
    return v.name
  end,
  __le = function(self, other)
    if not are_both_states(self, other) then
      return false
    end
    return self.idx <= other.idx
  end,
  __lt = function(self, other)
    if not are_both_states(self, other) then
      return false
    end
    return self.idx < other.idx
  end,
  __index = function(self, name)
    if name == 'is_state' then
      return true
    end
  end
}

function M.build_states(defs)
  local states = {}
  for i, name in ipairs(defs) do
    local state = setmetatable({ idx = i, name = name }, stateMeta)
    states[i] = state
    states[name] = state
  end
  return states
end

local SM = {}

local function empty_fn()
end

function SM:run_enter_state(state)
  local enter_fn = self.defs.enter and self.defs.enter[state] or empty_fn
  enter_fn(self.state)
end

function SM:run_exit_state(state)
  local enter_fn = self.defs.exit and self.defs.exit[state] or empty_fn
  enter_fn(self.state)
end

local function wrap_state_array(val)
  return val.is_state and { val } or val
end

local function canonicalize_event(event)
  return {
    from = wrap_state_array(event.from),
    to = event.to,
    transition = event.transition or function() end,
  }
end

function M.build(states, defs)
  local machine = {
    state = states[1],
    defs = defs,
  }
  local prototype = {}

  for name, infos in pairs(defs.events) do
    local event = canonicalize_event(infos)
    prototype[name] = function(self)
      if not vim.list_contains(event.from, self.state) then
        return false
      end
      local previous = self.state
      self:run_exit_state(previous)
      self.state = event.to
      event.transition(previous, self.state)
      self:run_enter_state(self.state)
      return true
    end
  end

  local ret = setmetatable(machine, { __index = vim.tbl_extend('error', SM, prototype)})
  ret:run_enter_state(states[1])
  return ret
end

local State = M.build_states {
  'NotLoaded',
  'Shimed',
  'Inited',
  'Imported',
  'Loaded',
}

return M
