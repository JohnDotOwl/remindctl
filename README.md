# remindctl

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS with **Sections** and **Tags** support.

## Features

- ✅ **Tags** - Full hashtag (#tag) support for organizing reminders
- ✅ **Sections** - Display and filter by reminder sections (custom groupings within lists)
- ✅ **Filters** - View by date, list, tag, completion status
- ✅ **JSON/Plain output** - Machine-readable formats for scripting
- ✅ **Fast** - Native Swift, runs locally

## Install

### Homebrew
```bash
brew install johndotowl/tap/remindctl
```

### From source
```bash
git clone https://github.com/JohnDotOwl/remindctl.git
cd remindctl
swift build -c release
# binary at .build/release/remindctl
```

## Requirements
- macOS 14+ (Sonoma or later)
- Swift 6.2+
- Reminders permission (System Settings → Privacy & Security → Reminders)

## Usage

### View Reminders
```bash
remindctl                      # show today (default)
remindctl today                # show today
remindctl tomorrow             # show tomorrow
remindctl week                 # show this week
remindctl overdue              # overdue reminders
remindctl upcoming             # upcoming reminders
remindctl completed            # completed reminders
remindctl all                  # all reminders
remindctl 2026-01-03           # specific date
remindctl --tag shopping       # filter by tag
remindctl --list Work          # filter by list
```

### Lists
```bash
remindctl list                  # list all reminder lists
remindctl list Work             # show reminders in a list
remindctl list Work --rename Office
remindctl list Work --delete
remindctl list Projects --create
```

### Tags
```bash
remindctl tags                  # list all tags with counts
remindctl tags shopping         # show reminders with #shopping tag
remindctl tags --json           # JSON output
```

### Add Reminders
```bash
remindctl add "Buy milk"
remindctl add --title "Call mom" --list Personal --due tomorrow
remindctl add "Buy milk" --tag shopping --tag urgent
remindctl add "Task" --tag shopping,urgent
remindctl add "Meeting" --due "2026-01-03 14:00" --priority high
```

### Edit Reminders
```bash
remindctl edit 1 --title "New title"
remindctl edit 4A83 --due tomorrow
remindctl edit 2 --priority high --notes "Call before noon"
remindctl edit 3 --clear-due
remindctl edit 1 --tag urgent          # add tag
remindctl edit 1 --remove-tag old      # remove tag
remindctl edit 1 --clear-tags          # remove all tags
```

### Complete & Delete
```bash
remindctl complete 1 2 3
remindctl delete 4A83 --force
```

### Permissions
```bash
remindctl status                # check permission status
remindctl authorize             # request Reminders access
```

## Output Formats
- `--json` - JSON arrays/objects (includes tags array and sectionName)
- `--plain` - Tab-separated lines
- `--quiet` - Counts only

## Date Formats
Accepted by `--due` and filters:
- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-03T12:34:56Z`)

## Tag Format
Tags are stored as hashtags in the reminder title:
- Valid characters: alphanumeric, hyphens, underscores
- Must start with a letter or number
- Case-insensitive matching, original case preserved

Examples: `#shopping`, `#work`, `#urgent`, `#buy-milk`

## Sections
Apple Reminders supports custom sections within lists (e.g., a "Books" list with "Fiction" and "Non-fiction" sections). 

Sections are displayed in output as `[ListName/SectionName]` and included in JSON as `sectionName`.

Sections are read-only (EventKit API limitation).

## Permissions
Run `remindctl authorize` to trigger the system prompt. If access is denied, enable Terminal (or remindctl) in System Settings → Privacy & Security → Reminders.

If running over SSH, grant access on the Mac that runs the command.

## Development
```bash
make remindctl ARGS="status"   # clean build + run
make check                     # lint + test + coverage gate
```

## License
MIT License - see LICENSE file
