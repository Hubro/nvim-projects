
# nvim-projects

Super simple Neovim plugin for quickly jumping to a project.

A project is any directory inside a list of project directories.

## Usage

```lua
require("nvim-projects").setup({
    init_filename = ".nvimrc.lua",
    project_dirs = {
        "~/projects",
        "~/my-company/projects",
    }
})
```

Then, you can use the Lua API to jump to projects:

```lua
-- Jumps to "~/projects/yang-parser"
require("nvim-projects").jump("yang-parser")
```

Or use the command, which helpfully has tab-completion:

```
:Project yang-parser
```

The `init_filename` setting is optional. If set, nvim-projects will look for a file with this name inside projects after
jumping to them. If found, the file will be sourced. This is useful for project specific settings.
