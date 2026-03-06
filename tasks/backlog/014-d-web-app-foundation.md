---
priority: medium
model: opus
estimated-cost: 3.0000
depends-on: 011
---

# Dispatch: Web app foundation (Next.js + Supabase Auth)

Set up the Dispatch web application with Next.js, Supabase Auth integration, base layout with sidebar, and routing structure. No feature pages yet — just the shell.

## Context

This is the web frontend for Dispatch. Users log in and see a dashboard with their projects, machines, sessions, and tasks. This task builds the foundation: auth flow, layout, navigation, and empty page shells.

## Tech stack

- **Next.js 15** (App Router)
- **Supabase Auth** (email/password for MVP)
- **Tailwind CSS 4**
- **shadcn/ui** for components
- TypeScript

## Deliverables

### 1. Project initialization

```
dispatch/web/
  package.json
  next.config.ts
  tailwind.config.ts
  tsconfig.json
  src/
    app/
    components/
    lib/
    types/
```

### 2. Supabase client setup

- `src/lib/supabase/client.ts` — browser client
- `src/lib/supabase/server.ts` — server client (for Server Components and Route Handlers)
- `src/lib/supabase/middleware.ts` — auth middleware for protected routes
- Environment variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`

### 3. Auth pages

- `src/app/(auth)/login/page.tsx` — email/password login form
- `src/app/(auth)/register/page.tsx` — registration form
- `src/app/(auth)/layout.tsx` — centered layout for auth pages
- Redirect to dashboard after login
- Redirect to login if not authenticated

### 4. Dashboard layout

- `src/app/(dashboard)/layout.tsx` — protected layout with sidebar
- Sidebar contains:
  - User info (email, avatar placeholder)
  - Navigation: Overview, Projects, Machines, Schedule
  - Projects list (from DB, loaded in layout)
  - Online machines indicator (count)
  - Logout button
- Responsive: sidebar collapses on mobile

### 5. Page shells (empty for now)

Create pages with basic headings — actual content comes in later tasks:

- `src/app/(dashboard)/page.tsx` — "Overview" (will be dashboard)
- `src/app/(dashboard)/projects/page.tsx` — "Projects"
- `src/app/(dashboard)/projects/[slug]/page.tsx` — "Project: {slug}"
- `src/app/(dashboard)/projects/[slug]/tasks/page.tsx` — "Tasks"
- `src/app/(dashboard)/sessions/[id]/page.tsx` — "Session: {id}"
- `src/app/(dashboard)/machines/page.tsx` — "Machines"
- `src/app/(dashboard)/schedule/page.tsx` — "Schedule"

### 6. Base components

- `src/components/sidebar.tsx` — navigation sidebar
- `src/components/page-header.tsx` — page title + breadcrumbs

### 7. Type definitions

- `src/types/database.ts` — TypeScript types matching the Supabase schema (can be generated with `supabase gen types typescript`)

## Affected files

- `dispatch/web/` — entire new package

## Acceptance criteria

- `npm run dev` starts the app
- Login/register flow works with Supabase Auth
- Unauthenticated users are redirected to login
- Authenticated users see the dashboard layout with sidebar
- All page routes are accessible and render their shell content
- Sidebar highlights the current page
- Responsive layout works on mobile
- TypeScript types match the database schema

## Constraints

- Keep it simple — no premature abstractions, no state management library
- Use Server Components by default, Client Components only where needed (auth forms, realtime)
- No custom design system — use shadcn/ui defaults
- `dispatch/web/` is self-contained; does not affect claude-runner files
