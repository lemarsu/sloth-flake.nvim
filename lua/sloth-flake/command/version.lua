return {
  complete = function() end,
  cmd = function()
    local version = require('sloth-flake.version')
    print(string.format('Sloth v%s', version()))
  end,
}
