local scan_dir = require("plenary.scandir").scan_dir

local M = {
  init_filename = nil,
  project_dirs = {},
}

local function is_dir(path)
  return vim.fn.isdirectory(path) == 1
end

function M.setup(input_opts)
  local opts = vim.deepcopy(input_opts)

  M.init_filename = nil
  M.project_dirs = {}

  if opts.init_filename then
    M.init_filename = opts.init_filename
    opts.init_filename = nil
  end

  if type(opts.project_dirs) ~= "table" then
    error("Option project_dirs is required and must be a table")
  end

  for _, path in ipairs(opts.project_dirs) do
    local normalized_path = vim.fs.normalize(path)

    if is_dir(normalized_path) then
      table.insert(M.project_dirs, normalized_path)
    else
      -- vim.notify(
      --   "Directory " .. normalized_path .. " does not exist",
      --   vim.log.levels.WARN,
      --   {
      --     title = "nvim-projects: Setup warning",
      --   }
      -- )
    end
  end

  opts.project_dirs = nil

  M.define_commands()

  -- There should be no keys left in the opts at this point
  if next(opts) ~= nil then
    vim.notify("Unknown options: " .. vim.inspect(opts), vim.log.levels.WARN, {
      title = "nvim-projects: Setup warning",
    })
  end
end

function M.jump_to(project)
  local projects = M.gather_projects()

  if projects[project] == nil then
    vim.notify("Unknown project: " .. project, vim.log.levels.ERROR, {
      title = "nvim-projects",
    })
    return
  elseif type(projects[project]) == "table" then
    vim.notify(
      'Found multiple paths for project "'
        .. project
        .. '":\n- '
        .. table.concat(projects[project], "\n- "),
      vim.log.levels.ERROR,
      {
        title = "nvim-projects",
      }
    )
  else
    local project_path = projects[project]

    vim.fn.chdir(project_path)

    vim.notify("Jumped to: " .. project_path, vim.log.levels.INFO, {
      title = "nvim-projects",
    })

    if M.init_filename ~= nil then
      -- Check if file M.init_filename exists in project_path
      if vim.fn.filereadable(M.init_filename) == 1 then
        vim.cmd("source " .. M.init_filename)

        vim.notify("Sourced " .. M.init_filename, vim.log.levels.INFO, {
          title = "nvim-projects",
        })
      end
    end
  end
end

-- Returns all project directories as a mapping from project name to full path
--
-- If the right-hand side of the mapping is a table rather than a string, it
-- means that the project exists in multiple project directories. This should
-- result in a warning if the user tries to jump to it.
--
function M.gather_projects()
  local projects = {}

  local function add_project(name, path)
    if is_dir(path) then
      if projects[name] == nil then
        projects[name] = path
      else
        if type(projects[name]) ~= "table" then
          projects[name] = { projects[name] }
        end

        table.insert(projects[name], path)
      end
    end
  end

  for _, project_dir in ipairs(M.project_dirs) do
    scan_dir(project_dir, {
      only_dirs = true,
      depth = 5,
      hidden = true,
      search_pattern = function(entry)
        return entry:sub(-5) == "/.git"
      end,
      on_insert = function(entry)
        local path = entry:sub(1, -6)
        local name = path:sub(#project_dir + 2, -1)

        add_project(name, path)
      end,
    })
  end

  return projects
end

function M.define_commands()
  vim.api.nvim_create_user_command("Project", function(opts)
    M.jump_to(opts.args)
  end, {
    nargs = 1,
    complete = function(_, _, _)
      return vim.fn.keys(M.gather_projects())
    end,
  })
end
return M
