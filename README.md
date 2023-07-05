
# nvim-projects

Super simple Neovim plugin for quickly jumping to a project.

Projects are found by recursively searching a list of project directories for
any directory containing a ".git" directory, which are assumed to be a project.

## Usage

```lua
require("nvim-projects").setup({
    project_dirs = {
        "~/projects",
        "~/my-company/projects",
    }

    -- Optional
    init_filename = ".nvimrc.lua",

    -- Optional
    after_jump = function(project_path)
        vim.cmd [[ NvimTreeOpen ]]
        vim.cmd [[ exec "normal \<c-w>\<c-w>" ]]
        vim.cmd [[ Telescope find_files ]]

        vim.notify("I just jumped to " .. project_path)
    end
})
```

Then, you can use the Lua API to jump to projects:

```lua
-- Jumps to "~/projects/yang-parser"
require("nvim-projects").jump("yang-parser")
```

Or use the provided command, which helpfully has tab-completion:

```
:Project yang-parser
```

Or use the built-in Telescope extension:

```lua
-- In your Telescope config
telescope.load_extension("nvim-projects")
```

```
:Telescope nvim-projects
```

## `opts.project_dirs`

Should be set to a list of directories. Paths can contain ~ and environment
variables. Each directory in this list is recursively scanned for directories
that contain a ".git" folder, which are assumed to be project directories.

If any directory in this list doesn't exist, it's ignored. This is nice if you
share the config on multiple machines that don't all have the same paths.

## `opts.init_filename`

The `init_filename` setting is optional. If set, nvim-projects will look for a
file with this name inside projects after jumping to them. If found, the file
will be sourced. This is useful for project specific settings. Example:

## `opts.after_jump`

You can also set `after_jump`, which will be executed after jumping to a
project. This can be a Vim command or a Lua function. The Lua function will be
called with the full path of the project you jumped to. Example:
