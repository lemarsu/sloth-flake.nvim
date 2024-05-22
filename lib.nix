{
  mkNeovimPkg = {
    pkgs,
    package ? pkgs.neovim-unwrapped,
    namePrefix ? "",
    nameSuffix ? "",
    dependencies ? [],
    dependenciesExtraArgs ? {},
    customRC ? "",
    ...
  }: let
    inherit (builtins) isPath;
    inherit (pkgs) lib;
    callPackage = lib.callPackageWith (pkgs // dependenciesExtraArgs);
    inherit (lib.lists) concatMap;
    inherit (lib.attrsets) attrNames;
    # inherit (lib.debug) traceIf traceSeq traceVal traceValSeq traceValFn;

    remotePluginToNeovimPlugin = p:
      pkgs.vimUtils.buildVimPlugin rec {
        inherit (p) src name;
        pname = name;
      };

    mkDep = dep:
      if isPath dep
      then mkDependencies (callPackage dep {})
      else if dep ? plugin
      then let
        inherit (dep) plugin;
      in
        if attrNames plugin == ["name" "src"]
        then [(remotePluginToNeovimPlugin plugin)]
        else [plugin]
      else [dep];
    mkDependencies = concatMap mkDep;

    neovimConfig = pkgs.neovimUtils.makeNeovimConfig {
      inherit customRC;
      plugins = mkDependencies dependencies;
    };
    pkg = pkgs.wrapNeovimUnstable package neovimConfig;
    # TODO nameSuffix is buggy :'(
    name = "${namePrefix}${pkg.name}${nameSuffix}";
  in
    pkg // {inherit name;};

  mkNeovimModule = {
    pluginsDir ? null,
    attrName ? "neoflake",
    self,
  }: {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.${attrName};
    inherit (builtins) baseNameOf isPath;
    inherit (lib) mkEnableOption mkIf mkOption types;
    # inherit (lib.debug) traceIf traceSeq traceVal traceValSeq traceValFn;
    inherit (lib.attrsets) attrNames optionalAttrs;
    inherit (lib.lists) concatMap filter foldl' map optional reverseList;
    inherit (lib.strings) concatStringsSep fileContents hasSuffix removePrefix removeSuffix replaceStrings;

    hm-file-type = import ./hm-file-type.nix {
      inherit (config.home) homeDirectory;
      inherit lib pkgs;
    };
    inherit (hm-file-type) fileTypeSubmodule;

    verbatimSubmodule = types.submodule {
      options = {
        path = mkOption {
          description = "path to copy from. Must be included in the flake folder.";
          type = types.path;
        };

        dest = mkOption {
          description = "dest into `.config/nvim`.";
          type = types.str;
        };
      };
    };

    remotePluginConfig = types.addCheck (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
        };

        src = mkOption {
          type = types.path;
        };
      };
    }) (mod: attrNames mod == ["name" "src"]);

    pluginWithConfigType = types.submodule {
      options = {
        enabled =
          mkEnableOption "enabled"
          // {
            description = ''
              Whether this plugin should be enabled. This option allows specific
              plugins to be disabled.
            '';
            default = true;
          };

        init = mkOption {
          type = types.nullOr (fileTypeSubmodule "${attrName}.plugins._.init" "{var}`xdg.configHome/nvim`" "nvim");
          description = "Script to init this plugin. Run before plugin load.";
          default = null;
        };

        config = mkOption {
          type = types.nullOr (fileTypeSubmodule "${attrName}.plugins._.config" "{var}`xdg.configHome/nvim`" "nvim");
          description = "Script to configure this plugin. Run after plugin load.";
          default = null;
        };

        main = mkOption {
          type = with types; nullOr str;
          description = "Name of the main module to load.";
          default = null;
        };

        ## Lazy options

        lazy = mkOption {
          type = types.bool;
          description = "Should this plugin be load lazily ?";
          default = false;
        };

        events = mkOption {
          type = with types; listOf str;
          description = "List of events on which the plugin should be loaded";
          default = [];
        };

        commands = mkOption {
          type = with types; listOf str;
          description = "List of commands on which the plugin should be loaded";
          default = [];
        };

        filetypes = mkOption {
          type = with types; listOf str;
          description = "List of filetypes on which the plugin should be loaded";
          default = [];
        };

        keys = mkOption {
          type = with types; listOf str;
          description = "List of keystrokes on which the plugin should be loaded";
          default = [];
        };

        priority = mkOption {
          type = with types; listOf str;
          description = ''
            Priority of the module. Influence the order of loading plugins.
            Highest values get loaded before.
          '';
          default = [];
        };

        dependencies = mkOption {
          # Should we accept strings?
          # type = with types; listOf (either strings package);
          type = with types; listOf package;
          description = ''
            Give the list of packages that should be loaded before the current one.
          '';
        };

        plugin = mkOption {
          type = with types; oneOf [path remotePluginConfig package];
          description = "The actual vim plugin package to load";
        };
      };
    };

    hasNixSuffix = hasSuffix ".nix";
    pluginNixFiles =
      if isNull pluginsDir
      then []
      else filter hasNixSuffix (lib.fileset.toList pluginsDir);

    pathToNeovimPlugin = src: let
      normalizeName = replaceStrings ["."] ["-"];
    in
      pkgs.vimUtils.buildVimPlugin rec {
        inherit src;
        pname = normalizeName (baseNameOf src);
        name = pname;
      };

    remotePluginToNeovimPlugin = p:
      pkgs.vimUtils.buildVimPlugin rec {
        inherit (p) src name;
        pname = name;
      };

    mkPlugin = plugin:
      if plugin ? plugin
      then let
        p = plugin.plugin;
      in
        if isPath p
        then pathToNeovimPlugin p
        else if attrNames p == ["name" "src"]
        then remotePluginToNeovimPlugin p
        else p
      else plugin;
  in {
    # imports = map wrapImport pluginNixFiles;
    imports = pluginNixFiles;

    options.${attrName} = {
      enable = mkEnableOption "${attrName} module";
      plugins = mkOption {
        description = "List all plugins to load";
        type = with types; listOf (oneOf [package pluginWithConfigType]);
      };

      includesVerbatim = mkOption {
        description = "Includes files as is in final .config/nvim.";
        type = with types; listOf (either path verbatimSubmodule);
        default = [];
      };

      defaultConfig = {
        enable = mkOption {
          description = "generate default configuration";
          type = types.bool;
          default = true;
        };
      };
    };

    config = let
      defaultPlugin = {
        enabled = true;
        init = null;
        config = null;
      };
      wrapIfNeeded = p:
        if p ? plugin
        then p
        else {plugin = p;};
      normalizedPlugins = map (p: defaultPlugin // (wrapIfNeeded p)) cfg.plugins;

      getText = submodule:
        if ! isNull submodule.text
        then submodule.text
        else fileContents submodule.source;

      wrapLuaInFunction = section: lua: ''
        -- begin ${section}
        (function()
        ${removeSuffix "\n" lua}
        end)();
        -- end ${section}
      '';

      pluginName = p:
        if p.plugin ? name
        then p.plugin.name
        else baseNameOf p.plugin;

      getInitText = p:
        optional (!(isNull p.init))
        (wrapLuaInFunction "init for ${pluginName p}" (getText p.init));

      getConfigText = p:
        optional (!(isNull p.config))
        (wrapLuaInFunction "config for ${pluginName p}" (getText p.config));

      initLua =
        concatStringsSep "\n"
        (concatMap getInitText normalizedPlugins);

      configLua =
        concatStringsSep "\n"
        (concatMap getConfigText normalizedPlugins);

      pathToString = filePath: let
        keyName = key: {
          inherit key;
          name = baseNameOf key;
        };
        list = map (n: n.name) (builtins.genericClosure {
          startSet = [(keyName filePath)];
          operator = item: let
            parent = dirOf item.key;
          in [(keyName parent)];
        });
      in
        concatStringsSep "/" (reverseList list);
      normalizeVerbatim = def:
        if def ? path && def ? dest
        then def
        else if ! isPath def
        then abort "Not a path nor a verbatim"
        else let
          fileStr = pathToString def;
          root = pathToString self.outPath;
        in {
          path = def;
          dest = removePrefix (root + "/") fileStr;
        };

      normalizedVerbatim = map normalizeVerbatim cfg.includesVerbatim;

      verbatimFiles =
        foldl'
        (memo: verbatim:
          memo
          // {
            "nvim/${verbatim.dest}" = {
              source = verbatim.path;
              recursive = true;
            };
          }) {}
        normalizedVerbatim;

      neoflakeFiles = let
        prefix = "nvim/lua/neoflake";
      in {
        ${prefix} = {
          source = ./lua/neoflake;
          recursive = true;
        };
        "${prefix}/initialize.lua".text = ''
          return function ()
          ${initLua}
          end
        '';
        "${prefix}/config.lua".text = ''
          return function ()
          ${configLua}
          end
        '';
      };

      defaultConfig = optionalAttrs cfg.defaultConfig.enable {
        "nvim/init.lua".source = ./lua/default_init.lua;
      };
    in
      mkIf cfg.enable {
        programs.neovim = {
          enable = true;
          vimAlias = true;
          viAlias = true;
          defaultEditor = true;
          withPython3 = true;
          withNodeJs = true;

          plugins = map mkPlugin cfg.plugins;
        };

        xdg.configFile =
          verbatimFiles
          // neoflakeFiles
          // defaultConfig;
      };
  };
}
