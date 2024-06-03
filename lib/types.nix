{yants, ...}: rec {
  # The runtime object
  runtimeType = with yants;
    struct "runtime" {
      # The version of the runtime
      version = option string;

      # The init configuration file
      init = option (either path string);

      # The content of the runtime directory
      src = any;
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
      name = either string stringList;
      pattern = either string stringList;
    };

  # The plugin type of dependencies
  pluginType = with yants; let
    stringList = list string;
  in
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
      events = option (eitherN [string eventType (list (either string eventType))]);

      # List of commands on which the plugin should be loaded
      cmd = option stringList;

      # List of filetypes on which the plugin should be loaded
      ft = option stringList;

      # List of keystrokes on which the plugin should be loaded
      # keys = option stringList;

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

      # An array of dependencies.
      dependencies = list dependency;

      # Extra argument to pass to dependencies files
      dependenciesExtraArgs = attrs any;

      # Runtime configuration
      runtime = runtimeType;

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
