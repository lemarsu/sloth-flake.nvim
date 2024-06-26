# sloth-flake.nvim

A [neovim] plugin and configuration management plugin, highly inspired by [lazy], using [nix].

<!-- TOC GFM -->

- [Description](#description)
- [Features](#features)
- [SemVer](#semver)
- [Installation](#installation)
  - [Flake installation](#flake-installation)
- [Usage](#usage)
- [Documentation](#documentation)
  - [nix](#nix)
    - [`mkPluginsFromInputs`](#mkpluginsfrominputs)
    - [`mkNeovimPkg`](#mkneovimpkg)
  - [neovim (lua)](#neovim-lua)
    - [Using default `init.lua`](#using-default-initlua)
    - [Using your own `init.lua`](#using-your-own-initlua)
    - [`:Sloth` command](#sloth-command)
      - [`list` subcommand](#list-subcommand)
      - [`load` subcommand](#load-subcommand)
      - [`version` subcommand](#version-subcommand)
    - [API](#api)

<!-- TOC -->

## Description

> `sloth-flake.nvim` is an alpha software. Please use caution when using it.

`sloth-flake.nvim` is both
- a [neovim] plugin to manage your plugins
- a [nix] flake to build your neovim package with your own configuration and plugins.

> :information_source: If you never heard of [nix] or you never used it, then this plugin is not for you.

## Features

- [X] Declare your plugin via `nix` files
  - [X] Declare nix package as dependencies
  - [X] Generate nix package from local files
- [X] Generate default `init.lua`
- [X] Accepts your own `init.lua`
- [X] Lazy load your plugins
  - [X] on command
  - [X] on filetype
  - [X] on event
  - [X] on keybinding
- [X] load plugins in order (via plugin `dependencies` property)
- [X] Have a `:Sloth` command to load or query your plugins
- [ ] Generate spell files on build (maybe)

## SemVer

This project will respect SemVer in the end, but will adopt a slightly different semantics in the beginning.

This project is considered alpha as long as the version is `0.0.x`, therefore
you can expect breaking change on each version. You can see the version as
`0.0.MAJOR`.

When this project will hit `0.1.0`, the project will be in beta phase. If a new
version have breaking change, then it will be `0.2.0` and `0.1.1` otherwise.
You can see the version as `0.MAJOR.MINOR`.

When this project will hit `1.0.0`, it will then follow full SemVer
(`MAJOR.MINOR.PATCH`).

## Installation

Only flake installation is supported.

### Flake installation

Import `sloth-flake.nvim` flake latest version:

```nix
inputs.sloth-flake.url = "github:lemarsu/sloth-flake.nvim";
```

You can give a specific version:

```nix
inputs.sloth-flake.url = "github:lemarsu/sloth-flake.nvim?tag=0.0.5";
```

## Usage

Once installed, you can call the `sloth-flake.lib.mkNeovimPkg` to build your neovim package.

`mkNeovimPkg` requires a *set* as argument with at least `pkgs` that represents your nixpkgs.

```nix
sloth-flake.lib.mkNeovimPkg {
  inherit pkgs;
  viAlias = true;
  vimAlias = true;
  runtime = {
    version = "0.1";
    src = sloth-flake.lib.sourcesWith ./. [
      ./after
      ./colors
      ./ftplugin
      ./lua
      ./plugin
      ./queries
    ];
  };

  dependencies = [
    rust-vim
    vim-openscad
    ./lsp
    {
      plugin = telescope-nvim;
      config = ./telescope.lua;
    }
  ];
}
```

## Documentation

### nix

#### `mkPluginsFromInputs`

`mkPluginsFromInputs` is a helper function that converts flake inputs (starting by `"plugin-"` by default) into vimPlugins.

Example:
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sloth-flake.url = "github:lemarsu/sloth-flake.nvim";
    utils.url = "github:numtide/flake-utils";

    plugin-base64 = {
      url = "github:moevis/base64.nvim";
      flake = false;
    };

    plugin-cellular-automaton = {
      url = "github:eandrju/cellular-automaton.nvim";
      flake = false;
    };
  };
  outputs = {utils, sloth-flake, ...}@inputs: let
    fu = utils.lib;
  in fu.eachDefaultSystem (system: let
    plugins = sloth-flake.lib.mkPluginsFromInputs {
      inherit pkgs inputs;
    };
  in {
    packages = rec {
      default = neovim;
      neovim = pkgs.callPackage ./package.nix {
        # By adding `plugins` here, we can use `with plugins; base64 cellular-automaton`, 
        inherit plugins sloth-flake;
      };
    };
  };
}
```

The function accepts the following attributes:

- `pkgs` **REQUIRED** the nixpkgs set.
- `inputs` **REQUIRED** the inputs from a flake.
- `predicate` **optional** predicate to filter input by name. By default, it's
  filter inputs with `hasPrefix "plugin-"`.
- `nameMap` **optional** function to change the key of the input in the resulting
  set. By default, the 7 first letters are removed, so to remove the "plugin-"
  prefix.
- `buildVimPlugin` **optional** function used to build the plugin. Defaults to
  `pkgs.vimUtils.buildVimPlugin`.

#### `mkNeovimPkg`

`mkNeovimPkg` requires only the `pkgs` argument.

Here's a list of all accepted arguments

| name                    | default                 | description                                                         |
|-------------------------|-------------------------|---------------------------------------------------------------------|
| `pkgs`                  | N/A                     | The nixpkgs set. **REQUIRED**                                       |
| `package`               | `pkgs.neovim-unwrapped` | The unwrapped neovim package to use                                 |
| `init`                  | `null`                  | The `init.lua` of your config (string, path or init config object)¹ |
| `runtime`               | `{}`                    | Your Runtime configuration (see below)                              |
| `dependencies`          | `[]`                    | A list of your dependencies (see below)                             |
| `dependenciesExtraArgs` | `{}`                    | Extra arguments to load your dependencies in other files            |
| `viAlias`               | `false`                 | Wether to create a `vi` alias to run neovim                         |
| `vimAlias`              | `false`                 | Wether to create a `vim` alias to run neovim                        |
| `vimdiffAlias`          | `false`                 | Wether to create a `vimdiff` alias to run neovim in diff mode       |
| `nvimdiffAlias`         | `false`                 | Wether to create a `nvimdiff` alias to run neovim in diff mode      |

> ¹ If you give your own `init.lua` as string or path, you'll have to call `sloth-flake` lua plugin yourself. See more below.

The init configuration object accepts the following properties:

| name       | default | description                                                                |
|------------|---------|----------------------------------------------------------------------------|
| `init`     | `null`  | Lua code call before plugins init. String or path.                         |
| `postInit` | `null`  | Lua code call after plugins init and before plugin config. String or path. |
| `config`   | `null`  | Luas cod call after plugins config. String or path.                        |

The Runtime configuration object accepts the following properties:

| name      | default | description                    |
|-----------|---------|--------------------------------|
| `version` | `null`  | The version of your runtime    |
| `src`     | `null`  | The content of your runtime    |

The dependencies is a list of element of either:
- path: the path of the file to load other dependencies
- package: a nix package of a neovim/vim plugin
- Plugin configuration object: an object describing a plugin and its configuration.

The Plugin configuration object accepts the following properties:

| name           | default | description                                                    |
|----------------|---------|----------------------------------------------------------------|
| `plugin`       | N/A     | The plugin to load² **REQUIRED**                               |
| `init`         | `null`  | Lua code (as string of path) to call before loading the plugin |
| `config`       | `null`  | Lua code (as string of path) to call after loading the plugin  |
| `dependencies` | `[]`    | The plugin dependencies³                                       |
| `lazy`         | `false` | Should the plugin be loaded lazily                             |
| `cmd`          | `[]`    | Command to put as place_holder to load the lazy plugin⁴        |
| `ft`           | `[]`    | Filetype to watch to load the lazy plugin⁴                     |
| `events`       | `[]`    | Events to watch to load the lazy plugin⁴⁵                      |
| `keymaps`      | `[]`    | Keymaps that when press will load the lazy plugin⁴⁶            |

> ² The plugin can be either a nix package or an object with only `name` and
> `src` as properties. The latter will be used to create a nix package of your
> plugin on the fly.

> ³ `nix` handles the installation of your plugin, therefore, this list is
> **NOT** to declare dependencies that the nix package of the plugin doesn't
> know. This will tell `sloth-flake` in what order your plugins should be
> loaded.

> ⁴ Setting this property implicitly set `lazy` to `true`.

> ⁵ Events can be a string, an Event object or a list of either. You can
> represent a simple event name and pattern with the following string format :
> "BufRead *.md".

> ⁶ Keymaps can be a string, an Keymap object or a list of either.

The Event configuration object accepts the following properties:

| name      | default | description                                                    |
|-----------|---------|----------------------------------------------------------------|
| `name`    | N/A     | The name of the event as string or list of string **REQUIRED** |
| `pattern` | `null`  | Pattern (as string or list of string) associated to the event  |

The Keymap configuration object accepts the following properties:

| name      | default | description                                        |
|-----------|---------|----------------------------------------------------|
| `mode`    | `"n"`   | The mode of the keymap as string or list of string |
| `mapping` | N/A     | The actual mapping **REQUIRED**                    |

### neovim (lua)

#### Using default `init.lua`

If your neovim configuration is only plugin configuration, `sloth-flake` will
give you a default `init.lua` that will load `sloth-flake` plugin that will, in
turn, load all your plugins. If you need more control over configuration
startup, please look at next section.

#### Using your own `init.lua`

You can provide your `init.lua`, but you must call `sloth-flake` your self.

```lua
-- Requiring sloth-flake plugin
local sloth_flake = require 'sloth-flake'

-- Before this point, no plugin nor configuration is loaded
-- You can configure what you need before loading any plugin.
sloth_flake.setup {
  -- This function is called after calling all optional `init` functions of your plugins
  -- but before loading those plugins
  post_init = function()
    -- [...]
  end
}

-- From here, your plugins are loaded and their optional `config` function called
```

#### `:Sloth` command

`sloth-flake` give a `Sloth` command that you can call to gather some
informations about or load your plugins.

Usage: `Sloth [command] [args...]`

If no arguments are given, the `Sloth` command will call the `list` subcommand.

##### `list` subcommand

Summary: List plugins.

Usage: `Sloth list [filter]`

- `filter`: filter the list of plugins.
  - `all`: list all declared plugins. Same as if no filter is given.
  - `loaded`: list only loaded plugins.
  - `notloaded`: list only not loaded plugins.

##### `load` subcommand

Summary: Load lazy plugins.

Usage: `Sloth load <plugin> [plugin [...]]`
- `plugin`: a plugin to load

##### `version` subcommand

Summary: Return Sloth version

Usage: `Sloth version`

#### API

The lua API is not really defined yet. This documentation will be completed then.

[neovim]: http://neovim.io/
[nix]: https://nixos.org
[lazy]: https://github.com/folke/lazy.nvim
