# Wingspan Scorer - Implementation Plan

## Context

Build a web app for scoring Wingspan board games. The project already has a fully configured Phoenix 1.8 + Ash 3.0 stack with magic link authentication, a User resource (email only), and Tailwind CSS. We need to add user profiles, a friending system, game creation with expansion support, a dynamic scoring form, and game history — all served through 3 routes: `/`, `/history`, `/friends`.

---

## Phase 1: User Profile Enhancement

**Goal**: Add `name` to User, create profile editing, set up routes and navigation.

### Modify: [user.ex](lib/wingspan_scorer/accounts/user.ex)
- Add `attribute :name, :string, allow_nil?: true, public?: true`
- Add `update :update_profile` action accepting `[:name]`
- Add `read :search` action with argument `:query` — filter with case-insensitive partial match on name/email
- Add policies: users can update own profile, any authenticated user can search

### Modify: [accounts.ex](lib/wingspan_scorer/accounts.ex)
- Add code_interface entries: `update_user_profile`, `search_users`

### Modify: [router.ex](lib/wingspan_scorer_web/router.ex)
- Replace `get "/", PageController, :home` with LiveView routes inside `ash_authentication_live_session`:
  ```elixir
  live "/", DashboardLive
  live "/history", HistoryLive
  live "/friends", FriendsLive
  ```

### Modify: [layouts.ex](lib/wingspan_scorer_web/components/layouts.ex)
- Add navbar with links to `/`, `/history`, `/friends`, user display + sign-out

### Create: [lib/wingspan_scorer_web/live/dashboard_live.ex](lib/wingspan_scorer_web/live/dashboard_live.ex)
- Stub LiveView with profile edit form using `AshPhoenix.Form.for_update(user, :update_profile)`
- Mode-based UI: `:home`, `:setup`, `:scoring`, `:results`

### Migration: `mix ash.codegen add_name_to_users`

---

## Phase 2: Friendship System

**Goal**: Bidirectional friendships (auto-accepted), search + add/remove friends UI.

### Create: [lib/wingspan_scorer/accounts/friendship.ex](lib/wingspan_scorer/accounts/friendship.ex)
- Ash Resource with `user_id` and `friend_id` (both `belongs_to :user`)
- `create` action sets `user_id` from actor, accepts `friend_id`
- Identity: unique on `[:user_id, :friend_id]`
- Bidirectional: on create, also create the reverse record via after_action hook
- On destroy, also destroy the reverse record

### Create: [lib/wingspan_scorer/accounts/changes/create_reverse_friendship.ex](lib/wingspan_scorer/accounts/changes/create_reverse_friendship.ex)
- After-action change that creates the `{friend_id, user_id}` reverse record

### Create: [lib/wingspan_scorer/accounts/changes/destroy_reverse_friendship.ex](lib/wingspan_scorer/accounts/changes/destroy_reverse_friendship.ex)
- After-action change that destroys the reverse record on friendship removal

### Modify: [user.ex](lib/wingspan_scorer/accounts/user.ex)
- Add `has_many :friendships, Friendship` and `many_to_many :friends, User, through: Friendship`

### Modify: [accounts.ex](lib/wingspan_scorer/accounts.ex)
- Register Friendship resource, add code_interface: `add_friend`, `remove_friend`

### Create: [lib/wingspan_scorer_web/live/friends_live.ex](lib/wingspan_scorer_web/live/friends_live.ex)
- Search bar → calls `:search` action, filters out self + existing friends
- Search results with "Add Friend" button
- Friends list with "Remove" button

### Migration: `mix ash.codegen create_friendships`

---

## Phase 3: Games Domain

**Goal**: Game and GamePlayer resources for storing games and scores.

### Create: [lib/wingspan_scorer/games.ex](lib/wingspan_scorer/games.ex)
- New Ash Domain with Game and GamePlayer resources
- Code interfaces: `create_game`, `get_game`, `list_my_games`, `complete_game`, `create_game_player`, `update_game_player_scores`

### Create: [lib/wingspan_scorer/games/game.ex](lib/wingspan_scorer/games/game.ex)
- Attributes: `expansions` (array of atoms: `:base`, `:european`, `:oceania`, `:asia`, `:americas`), `played_at` (date), `completed` (boolean)
- `belongs_to :creator, User` and `has_many :game_players, GamePlayer`
- Actions: `create` (sets creator from actor), `complete`, `read`, `destroy`
- Policies: creator can manage; players can read

### Create: [lib/wingspan_scorer/games/game_player.ex](lib/wingspan_scorer/games/game_player.ex)
- Core score attributes: `bird_points`, `bonus_card_points`, `end_of_round_goals`, `eggs`, `cached_food`, `tucked_cards` (all integer, default 0)
- Oceania attributes: `nectar_forest`, `nectar_grassland`, `nectar_wetland` (integer, default 0)
- Asia attribute: `duet_map_points` (integer, default 0)
- `guest_name` (string, nullable) for non-registered players
- `belongs_to :game, Game` (required) and `belongs_to :user, User` (nullable for guests)
- Calculations: `display_name` (user name or guest_name), `base_total`
- Validations: all score fields >= 0
- Actions: `create`, `update_scores`

### Modify: [config.exs](config/config.exs)
- Register `WingspanScorer.Games` in `ash_domains`

### Migration: `mix ash.codegen create_games_domain`

---

## Phase 4: Game Creation (Dashboard)

**Goal**: Build the game setup flow on the dashboard.

### Modify: [dashboard_live.ex](lib/wingspan_scorer_web/live/dashboard_live.ex)
- **Home mode**: "New Game" button, list of recent incomplete games
- **Setup mode**:
  - Expansion checkboxes (Base always selected)
  - Player selection: current user always included, friends as checkboxes, "Add Guest" button with text inputs
  - "Start Game" → creates Game + GamePlayer records, transitions to scoring mode

---

## Phase 5: Dynamic Scoring Form

**Goal**: Expansion-aware scoring form with real-time totals.

### Create: [lib/wingspan_scorer_web/live/scoring_form_component.ex](lib/wingspan_scorer_web/live/scoring_form_component.ex)
- Table/grid layout: columns = players, rows = scoring categories
- **Always shown**: Bird Points, Bonus Cards, End-of-Round Goals, Eggs, Cached Food, Tucked Cards
- **If `:oceania` in expansions**: Nectar per habitat (Forest, Grassland, Wetland) + computed Nectar VP row
- **If `:asia` in expansions**: Duet Map Points
- Real-time total computation on `phx-change`
- **Nectar VP logic**: Per habitat, rank players by nectar count. 1st place = 5VP, 2nd = 2VP. Ties split evenly, rounded down. Computed in LiveView (not persisted).
- Winner highlight on the total row
- "Save Game" → updates all GamePlayer scores, marks game completed

---

## Phase 6: History Page

### Create: [lib/wingspan_scorer_web/live/history_live.ex](lib/wingspan_scorer_web/live/history_live.ex)
- Query games where user is creator or player, ordered by date desc
- List view: date, expansion tags, player names, winner
- Click to expand → full scoring breakdown (reuse scoring component in read-only mode)

---

## Phase 7: Polish

- Empty states for no games, no friends
- Form validation error display using AshPhoenix patterns
- Responsive layout for mobile (Tailwind)
- Clean up unused PageController and related files

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Friendship model | Bidirectional (2 rows per pair) | Simpler queries and Ash policies |
| Score storage | Flat attributes on GamePlayer | Avoids unnecessary joins, only ~10 fields |
| Nectar VP | Computed in LiveView, not stored | Cross-player calculation, always recomputable from raw data |
| Dashboard modes | Assign-based mode switching | Keeps route count to exactly 3 as specified |
| Guest players | GamePlayer with `user_id: nil` + `guest_name` | Simple, no separate guest resource needed |

---

## Files Summary

**New files (10):**
- `lib/wingspan_scorer/accounts/friendship.ex`
- `lib/wingspan_scorer/accounts/changes/create_reverse_friendship.ex`
- `lib/wingspan_scorer/accounts/changes/destroy_reverse_friendship.ex`
- `lib/wingspan_scorer/games.ex`
- `lib/wingspan_scorer/games/game.ex`
- `lib/wingspan_scorer/games/game_player.ex`
- `lib/wingspan_scorer_web/live/dashboard_live.ex`
- `lib/wingspan_scorer_web/live/friends_live.ex`
- `lib/wingspan_scorer_web/live/history_live.ex`
- `lib/wingspan_scorer_web/live/scoring_form_component.ex`

**Modified files (5):**
- `lib/wingspan_scorer/accounts/user.ex`
- `lib/wingspan_scorer/accounts.ex`
- `lib/wingspan_scorer_web/router.ex`
- `lib/wingspan_scorer_web/components/layouts.ex`
- `config/config.exs`

---

## Verification

1. `mix ash.codegen` after each phase to generate migrations
2. `mix ecto.migrate` to apply
3. `mix test` after each phase
4. Manual testing:
   - Sign in via magic link → lands on dashboard
   - Edit profile name
   - Search and add a friend at `/friends`
   - Create a game with Oceania expansion + guest player
   - Fill in scores, verify nectar VP auto-calculates
   - Save game, verify it appears in `/history`
   - View game details in history
