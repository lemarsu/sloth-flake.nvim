{yants, ...}: let
  stringList = with yants; list string;
  stringOrStringList = with yants; either string stringList;
  stringOrStringListOr = type:
    with yants;
      option (eitherN [string type (list (either string type))]);
in rec {
  # The runtime object
  runtimeType = with yants;
    struct "runtime" {
      # The version of the runtime
      version = option string;

      # The content of the runtime directory
      src = any;
    };

  neovimInitType = with yants;
    struct "neovimInit" {
      # Lua code to call before plugins loaded
      init = option (either string path);
      # Lua code called after init but before import
      postInit = option (either string path);
      # Lua code called after all plugins are loaded
      config = option (either string path);
    };

  # As simple remote plugin definition
  basicPluginType = with yants;
    struct "basicPlugin" {
      # The name of your plugin.
      name = string;
      # The sources of your plugin
      # TODO What is the type of a source ?
      src = any;
    };

  eventType = with yants;
    struct "event" {
      # The name of the event
      name = stringOrStringList;
      # The pattern of the event
      pattern = stringOrStringList;
    };

  keymapType = with yants;
    struct "keymap" {
      # The mode of the keymap
      mode = option stringOrStringList;
      # The mapping of the keymap
      mapping = stringOrStringList;
    };

  # The plugin type of dependencies
  pluginType = with yants;
    struct "plugin" {
      # Whether this plugin should be enabled. This option allows specific
      # plugins to be disabled.
      # enable = option bool;

      # The init configuration of your plugin.
      # This should be called before loading your plugin.
      init = option (either path string);

      # The configuration of your plugin.
      # This should be called after loading your plugin.
      config = option (either path string);

      # Ensure thoses plugins are loaded before the current one
      plugin = either drv basicPluginType;

      # Ensure thoses plugins are loaded before the current one
      dependencies = option (list drv);

      # Should this plugin be load lazily ?
      lazy = option bool;

      # List of events on which the plugin should be loaded
      events = option (stringOrStringListOr eventType);

      # List of commands on which the plugin should be loaded
      cmd = option stringList;

      # List of filetypes on which the plugin should be loaded
      ft = option stringList;

      # List of keystrokes on which the plugin should be loaded
      keymaps = option (stringOrStringListOr keymapType);

      # Priority of the module. Influence the order of loading plugins.
      # Highest values get loaded before.
      # priority = option int;
    };

  # A dependency.
  # TODO Complete doc
  dependency = with yants; eitherN [path drv pluginType];

  mkNeovimPkgOptions = with yants;
    struct "mkNeovimPkgOptions" {
      # The configuration of mkNeovimPkg
      pkgs = attrs any;

      # The neovim package to wrap with your conifguration.
      # Default is pkgs.neovim-unwrapped
      package = option drv;

      # init.lua configuration
      init = option (eitherN [string path neovimInitType]);

      # An array of dependencies.
      dependencies = option (list dependency);

      # Extra argument to pass to dependencies files
      dependenciesExtraArgs = option (attrs any);

      # Runtime configuration
      runtime = option runtimeType;

      # Create a vi alias
      viAlias = option bool;

      # Create a vim alias
      vimAlias = option bool;

      # Create a vimdiff alias to run neovim in diff mode
      vimdiffAlias = option bool;

      # Create a nvimdiff alias to run neovim in diff mode
      nvimdiffAlias = option bool;
    };
}
