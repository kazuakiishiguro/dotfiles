-- Application bindings.
-- Replace defaults explicitly so each shortcut runs only one command.
local function bind(keys, ...)
  hl.unbind(keys)
  o.bind(keys, ...)
end

bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omarchy = "browser --private" })
bind("SUPER + SHIFT + M", "Music", { omarchy = "spotify" })
bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp", focus = true })
bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
bind("SUPER + SHIFT + D", "Docker", { tui = "omarchy-launch-docker-tui" })
bind("SUPER + SHIFT + G", "Signal", { omarchy = "signal" })
bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })
bind("SUPER + SHIFT + SLASH", "Passwords", { omarchy = "1password" })

-- Web app bindings.
bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })
bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" })
bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
bind("SUPER + SHIFT + CTRL + G", "Google Messages", { webapp = "https://messages.google.com/web/conversations", focus = true })
bind("SUPER + SHIFT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })
bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })

-- Add extra bindings below.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Personal bindings (migrated from the pre-Lua bindings.conf).
bind("SUPER + SHIFT + CTRL + N", "Org capture", 'uwsm-app -- alacritty --class org-zettel-edit -e emacsclient -t -a "" --eval "(org-capture)"')
bind("SUPER + SHIFT + Z", "Zettelkasten", "brave --app=http://localhost:8080")
bind("SUPER + SHIFT + S", "Syncthing", { webapp = "http://localhost:8384" })

-- Overwrite existing bindings with hl.unbind() first if needed.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { omarchy = "walker -m symbols" })
