local M = {}

local labels = {
  CommitCommentEvent = "Commented on a commit",
  CreateEvent = "Created",
  DeleteEvent = "Deleted",
  ForkEvent = "Forked",
  GollumEvent = "Updated the wiki for",
  IssueCommentEvent = "Commented on an issue in",
  IssuesEvent = "Updated an issue in",
  MemberEvent = "Updated collaborators in",
  PublicEvent = "Made public",
  PullRequestEvent = "Updated a pull request in",
  PullRequestReviewEvent = "Reviewed a pull request in",
  PullRequestReviewCommentEvent = "Commented on a review in",
  PushEvent = "Pushed to",
  ReleaseEvent = "Published a release in",
  WatchEvent = "Starred",
}

local icons = {
  CreateEvent = "+",
  DeleteEvent = "-",
  ForkEvent = "⑂",
  IssueCommentEvent = "◆",
  IssuesEvent = "!",
  PullRequestEvent = "↗",
  PullRequestReviewEvent = "✓",
  PullRequestReviewCommentEvent = "◆",
  PushEvent = "↑",
  ReleaseEvent = "◇",
  WatchEvent = "★",
}

local function value(root, ...)
  local current = root
  for _, key in ipairs({ ... }) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[key]
  end
  return current
end

local function sentence(event)
  local payload = event.payload or {}
  local repo = value(event, "repo", "name") or "an unknown repository"
  local kind = event.type or "ActivityEvent"

  if kind == "PushEvent" then
    local count = payload.size or #(payload.commits or {})
    local branch = (payload.ref or ""):match("([^/]+)$")
    if count == 0 then
      return ("Pushed to %s%s"):format(repo, branch and (" · " .. branch) or "")
    end
    local noun = count == 1 and "commit" or "commits"
    return ("Pushed %d %s to %s%s"):format(count, noun, repo, branch and (" · " .. branch) or "")
  end

  if kind == "PullRequestEvent" then
    local number = value(payload, "pull_request", "number") or payload.number
    local title = value(payload, "pull_request", "title")
    return ("%s pull request%s in %s%s"):format(
      payload.action or "Updated",
      number and (" #" .. number) or "",
      repo,
      title and (" · " .. title) or ""
    )
  end

  if kind == "IssueCommentEvent" then
    local number = value(payload, "issue", "number")
    local title = value(payload, "issue", "title")
    return ("Commented on %s%s in %s%s"):format(
      value(payload, "issue", "pull_request") and "pull request" or "issue",
      number and (" #" .. number) or "",
      repo,
      title and (" · " .. title) or ""
    )
  end

  if kind == "IssuesEvent" then
    local number = value(payload, "issue", "number")
    local title = value(payload, "issue", "title")
    return ("%s issue%s in %s%s"):format(
      payload.action or "Updated",
      number and (" #" .. number) or "",
      repo,
      title and (" · " .. title) or ""
    )
  end

  if kind == "CreateEvent" or kind == "DeleteEvent" then
    local target = payload.ref_type or "item"
    local ref = payload.ref and (" " .. payload.ref) or ""
    return ("%s %s%s in %s"):format(labels[kind], target, ref, repo)
  end

  if kind == "ReleaseEvent" then
    local tag = value(payload, "release", "tag_name")
    return ("%s%s in %s"):format(labels[kind], tag and (" " .. tag) or "", repo)
  end

  return ("%s %s"):format(labels[kind] or kind:gsub("Event$", ""), repo)
end

local function detail(event)
  if event.type == "PushEvent" then
    local commits = value(event, "payload", "commits") or {}
    local message = commits[#commits] and commits[#commits].message
    return message and message:match("[^\r\n]+") or nil
  end
  return nil
end

local function event_url(event)
  local repo = value(event, "repo", "name")
  if not repo then
    return "https://github.com"
  end

  local base = "https://github.com/" .. repo
  local payload = event.payload or {}
  if event.type == "PullRequestEvent" then
    local number = value(payload, "pull_request", "number") or payload.number
    return number and (base .. "/pull/" .. number) or base
  elseif event.type == "IssueCommentEvent" then
    return value(payload, "comment", "html_url") or base
  elseif event.type == "PullRequestReviewEvent" then
    return value(payload, "review", "html_url") or value(payload, "pull_request", "html_url") or base
  elseif event.type == "PullRequestReviewCommentEvent" then
    return value(payload, "comment", "html_url") or value(payload, "pull_request", "html_url") or base
  elseif event.type == "IssuesEvent" then
    local number = value(payload, "issue", "number")
    return number and (base .. "/issues/" .. number) or base
  elseif event.type == "ReleaseEvent" then
    local tag = value(payload, "release", "tag_name")
    return tag and (base .. "/releases/tag/" .. tag) or (base .. "/releases")
  elseif event.type == "PushEvent" and payload.head then
    return base .. "/commit/" .. payload.head
  end
  return base
end

function M.describe(event)
  return {
    icon = icons[event.type] or "●",
    text = sentence(event),
    detail = detail(event),
    url = event_url(event),
  }
end

return M
