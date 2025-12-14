# Getting Started with Social Scribe - Elixir Beginner's Guide

Welcome to Social Scribe! This guide will help you understand the project structure and where to start if you're new to Elixir.

## 📚 What is This Project?

Social Scribe is a **Phoenix LiveView** application (built with Elixir) that:
- Connects to Google Calendar
- Automatically sends AI notetakers to meetings
- Transcribes meetings using Recall.ai
- Generates follow-up emails and social media posts using Google Gemini AI
- Posts content to LinkedIn and Facebook

## 🏗️ Project Structure Overview

### Key Directories

```
lib/
├── social_scribe/          # Core business logic (the "contexts")
│   ├── accounts.ex         # User management & authentication
│   ├── calendar.ex         # Calendar event management
│   ├── meetings.ex         # Meeting & transcript management
│   ├── automations.ex      # Social media automation rules
│   ├── bots.ex             # Recall.ai bot management
│   └── workers/            # Background job workers (Oban)
│
└── social_scribe_web/      # Web layer (Phoenix)
    ├── router.ex           # URL routing (START HERE for routes!)
    ├── controllers/        # HTTP request handlers
    ├── live/               # LiveView pages (real-time UI)
    └── components/         # Reusable UI components
```

## 🚀 Entry Points - Where to Start

### 1. **Application Start** (`lib/social_scribe/application.ex`)
This is where the application boots up. It starts:
- Database connection (PostgreSQL via Ecto)
- Background job processor (Oban)
- Web server (Phoenix Endpoint)

**Key Concept**: In Elixir, applications use the OTP supervision tree. This file defines what processes start when the app runs.

### 2. **Router** (`lib/social_scribe_web/router.ex`)
**THIS IS YOUR MAIN ENTRY POINT FOR UNDERSTANDING ROUTES!**

The router defines all URLs in your app:
- `/` → Landing page (for non-authenticated users)
- `/dashboard` → Main dashboard (requires login)
- `/auth/:provider` → OAuth login (Google, LinkedIn, Facebook)
- `/meetings` → List of meetings
- `/automations` → Manage automation rules
- `/settings` → User settings

**Key Routes:**
```elixir
# Line 77: Main dashboard
live "/", HomeLive

# Line 82-84: Meeting pages
live "/meetings", MeetingLive.Index, :index
live "/meetings/:id", MeetingLive.Show, :show

# Line 86-88: Automation management
live "/automations", AutomationLive.Index, :index
```

### 3. **LiveView Pages** (`lib/social_scribe_web/live/`)
These are the interactive pages. Each LiveView module has:
- A `.ex` file (Elixir logic)
- A `.html.heex` file (HTML template)

**Start with:**
- `home_live.ex` - Main dashboard
- `meeting_live/index.ex` - Meeting list
- `meeting_live/show.ex` - Individual meeting details

### 4. **Context Modules** (`lib/social_scribe/`)
These contain your business logic. In Phoenix, "contexts" group related functionality.

**Key Contexts:**
- **`accounts.ex`** - User authentication, credentials management
- **`calendar.ex`** - Calendar event syncing
- **`meetings.ex`** - Meeting and transcript management
- **`automations.ex`** - Social media automation rules
- **`bots.ex`** - Recall.ai bot management

## 🔑 Key Elixir Concepts for This Project

### 1. **Modules and Functions**
```elixir
defmodule SocialScribe.Accounts do
  def get_user!(id) do
    # Function body
  end
end
```
- `defmodule` defines a module (like a class in OOP)
- `def` defines a public function
- Functions return the last expression

### 2. **Pattern Matching**
```elixir
def get_user_by_email(email) when is_binary(email) do
  Repo.get_by(User, email: email)
end
```
- Elixir uses pattern matching instead of assignment
- `when` clauses add guards (conditions)

### 3. **Pipelines** (`|>`)
```elixir
%User{}
|> User.registration_changeset(attrs)
|> Repo.insert()
```
- The pipe operator passes the result to the next function
- Makes code readable and flows top-to-bottom

### 4. **Structs** (like objects)
```elixir
%User{email: "user@example.com", id: 1}
```
- Structs are like maps with defined keys
- Defined in schema files (e.g., `accounts/user.ex`)

### 5. **Tuples for Success/Error**
```elixir
{:ok, user}  # Success
{:error, changeset}  # Error
```
- Common pattern in Elixir
- `:ok` and `:error` are atoms (constants)

### 6. **LiveView** (Real-time UI)
```elixir
defmodule SocialScribeWeb.HomeLive do
  use SocialScribeWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
  
  def handle_event("toggle", _params, socket) do
    # Handle button click
    {:noreply, socket}
  end
end
```
- `mount/3` - Called when page loads
- `handle_event/3` - Handles user interactions (clicks, form submits)
- Updates happen in real-time without full page reloads

## 📖 Recommended Learning Path

### Step 1: Understand the Flow
1. **User visits** `/` → `LandingLive` (landing page)
2. **User clicks "Login"** → `/auth/google` → OAuth flow
3. **After login** → `/dashboard` → `HomeLive` (shows calendar events)
4. **User toggles recording** → Background job creates Recall.ai bot
5. **After meeting** → Bot polls for transcript → AI generates content

### Step 2: Explore Key Files
Start reading in this order:

1. **`router.ex`** - See all routes
2. **`home_live.ex`** - Main dashboard logic
3. **`accounts.ex`** - How users are managed
4. **`meetings.ex`** - How meetings are stored/retrieved
5. **`workers/bot_status_poller.ex`** - Background job example

### Step 3: Follow a Feature
Pick one feature and trace it through:

**Example: "View a Meeting"**
1. User clicks meeting → `router.ex` line 83
2. Routes to → `meeting_live/show.ex`
3. `mount/3` calls → `Meetings.get_meeting!/1`
4. `meetings.ex` queries database
5. Template renders → `meeting_live/show.html.heex`

## 🛠️ Common Tasks

### Running the App
```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
# Visit http://localhost:4000
```

### Database Operations
```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset
```

### Interactive Elixir Shell
```bash
# Start with the app loaded
iex -S mix phx.server

# Then you can test functions:
iex> SocialScribe.Accounts.list_users()
```

## 📁 File Naming Conventions

- **`.ex`** - Compiled Elixir code
- **`.exs`** - Elixir scripts (tests, config)
- **`.heex`** - HTML + Elixir templates
- **`_test.exs`** - Test files

## 🎯 Where You Are Now

You're currently looking at **`lib/social_scribe/accounts.ex`** (line 36). This file:
- Manages user authentication
- Handles OAuth credentials (Google, LinkedIn, Facebook)
- Provides functions to get/create/update users

**Key functions in this file:**
- `get_user!/1` - Get a user by ID
- `register_user/1` - Create a new user
- `get_or_create_user_from_auth/1` - Create user from OAuth

## 🔍 Next Steps

1. **Read the router** to understand all routes
2. **Pick a LiveView page** and read both the `.ex` and `.html.heex` files
3. **Follow a user action** from click → database → response
4. **Check out the tests** in `test/` to see examples of how things work

## 📚 Learning Resources

- **Elixir School**: https://elixirschool.com/
- **Phoenix Guides**: https://hexdocs.pm/phoenix/overview.html
- **LiveView Guide**: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html

## 💡 Tips

- Use `IO.inspect/2` to debug (like `console.log` in JavaScript)
- Elixir has great documentation - press `K` in IEx to see docs
- Pattern matching is powerful - use it everywhere!
- Functions are data - you can pass them around

Happy coding! 🚀





