# Dispatch — Диспетчерская для AI-агентов

## Архитектура системы

---

## 1. Общее видение

Dispatch — веб-сервис для управления и мониторинга сессий Claude Code
на нескольких машинах и проектах. Позволяет:

- Видеть в реальном времени, что делает каждый агент на каждой машине
- Запускать задачи удалённо (в т.ч. ночные пакеты)
- Утром открыть дашборд и увидеть полную картину ночной работы
- Понимать, где затыки и куда направить внимание
- Хранить историю всех сессий, задач и результатов

---

## 2. Компоненты системы

```
┌─────────────────────────────────────────────────────────────┐
│                      Dispatch Web App                        │
│                   (Next.js + Supabase)                        │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐  │
│  │ Dashboard │  │ Projects │  │  Sessions │  │   Tasks    │  │
│  │ Overview  │  │   List   │  │  Detail   │  │  Manager   │  │
│  └──────────┘  └──────────┘  └───────────┘  └────────────┘  │
└─────────────────────────┬───────────────────────────────────┘
                          │ Supabase Realtime + REST API
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                     Supabase Backend                          │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐  │
│  │ PostgreSQL│  │ Realtime │  │   Auth    │  │  Edge      │  │
│  │  Tables   │  │  Subscr. │  │           │  │  Functions │  │
│  └──────────┘  └──────────┘  └───────────┘  └────────────┘  │
└─────────────────────────┬───────────────────────────────────┘
                          │ REST API (heartbeats, events)
                          │
      ┌───────────────────┼───────────────────┐
      │                   │                   │
┌─────┴─────┐      ┌─────┴─────┐      ┌─────┴─────┐
│  Machine 1 │      │  Machine 2 │      │  Machine N │
│  (MacBook)  │      │  (Linux)   │      │  (VPS)     │
│             │      │             │      │             │
│ Claude Code │      │ Claude Code │      │ Claude Code │
│   + Hooks   │      │   + Hooks   │      │   + Hooks   │
│   + Agent   │      │   + Agent   │      │   + Agent   │
└─────────────┘      └─────────────┘      └─────────────┘
```

---

## 3. База данных (PostgreSQL / Supabase)

### Таблица `machines` — зарегистрированные машины

```sql
create table machines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  name text not null,                    -- "MacBook Pro", "Linux Workstation"
  hostname text not null,                -- системный hostname
  machine_key text unique not null,      -- API-ключ для аутентификации хука
  last_heartbeat timestamptz,
  is_online boolean default false,
  meta jsonb default '{}'::jsonb,        -- ОС, архитектура и т.д.
  created_at timestamptz default now()
);
```

### Таблица `projects` — проекты

```sql
create table projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  name text not null,                    -- "Loom.ru", "DeploySaas"
  slug text unique not null,             -- "loom-ru"
  repo_path text,                        -- "/home/sergey/projects/loom-ru"
  stack text,                            -- "Next.js / TypeScript"
  color text default '#3B82F6',          -- цвет в UI
  created_at timestamptz default now()
);
```

### Таблица `sessions` — сессии Claude Code

```sql
create table sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  machine_id uuid references machines(id) not null,
  project_id uuid references projects(id),
  session_code text not null,            -- session_id из Claude Code
  branch text,                           -- git branch
  status text default 'active',          -- active, idle, waiting, done, error, stale
  task_description text,                 -- что делает агент
  model text,                            -- claude-sonnet-4, claude-opus-4
  context_used integer,                  -- % использованного контекста
  tokens_used integer default 0,
  started_at timestamptz default now(),
  last_event_at timestamptz default now(),
  finished_at timestamptz,
  error_summary text,                    -- если статус error
  meta jsonb default '{}'::jsonb
);
```

### Таблица `events` — события жизненного цикла

```sql
create table events (
  id bigint generated always as identity primary key,
  session_id uuid references sessions(id) not null,
  event_type text not null,              -- session_start, tool_use, tool_result,
                                         -- notification, stop, error, heartbeat
  tool_name text,                        -- Bash, Edit, Write, Read ...
  summary text,                          -- краткое описание что произошло
  duration_ms integer,                   -- сколько заняло выполнение
  details jsonb default '{}'::jsonb,     -- полный контекст из hook stdin
  created_at timestamptz default now()
);

-- Индекс для быстрых запросов по времени
create index idx_events_session_time on events (session_id, created_at desc);
create index idx_events_type on events (event_type, created_at desc);
```

### Таблица `tasks` — задачи для выполнения (очередь)

```sql
create table tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  project_id uuid references projects(id) not null,
  machine_id uuid references machines(id),            -- на какой машине запустить
  title text not null,
  prompt text not null,                                -- промпт для claude -p
  priority integer default 0,                          -- выше = важнее
  depends_on uuid[],                                   -- зависимости от других задач
  status text default 'queued',                        -- queued, running, done, error, cancelled
  session_id uuid references sessions(id),             -- привязка к сессии
  max_turns integer default 50,
  scheduled_at timestamptz,                            -- когда запустить (для ночных)
  started_at timestamptz,
  finished_at timestamptz,
  result_summary text,
  error_message text,
  created_at timestamptz default now()
);
```

### RLS-политики

```sql
-- Все таблицы: пользователь видит только свои данные
alter table machines enable row level security;
alter table projects enable row level security;
alter table sessions enable row level security;
alter table events enable row level security;
alter table tasks enable row level security;

create policy "users own machines" on machines
  for all using (auth.uid() = user_id);

create policy "users own projects" on projects
  for all using (auth.uid() = user_id);

create policy "users own sessions" on sessions
  for all using (auth.uid() = user_id);

create policy "users see own events" on events
  for select using (
    session_id in (select id from sessions where user_id = auth.uid())
  );

create policy "users own tasks" on tasks
  for all using (auth.uid() = user_id);
```

---

## 4. Dispatch Agent (на каждой машине)

Лёгкий скрипт (Python или Node), который:

1. Регистрирует машину в Dispatch при первом запуске
2. Отправляет heartbeat каждые 30 сек
3. Вызывается из Claude Code hooks и отправляет события в Supabase
4. Слушает очередь задач и запускает `claude -p` когда приходит задача

### Установка на машине

```bash
# Установка
npm install -g @dispatch/agent
# или
pip install dispatch-agent

# Регистрация машины
dispatch init --name "MacBook Pro" --url https://your-project.supabase.co

# Это создаёт:
# 1. ~/.dispatch/config.json с machine_key и supabase URL
# 2. Настраивает Claude Code hooks в ~/.claude/settings.json
# 3. Запускает фоновый процесс для heartbeat + task listener
```

### Hooks конфигурация (автоматически добавляется)

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "dispatch report session_start"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write|MultiEdit|Bash",
      "hooks": [{
        "type": "command",
        "command": "dispatch report tool_use"
      }]
    }],
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "dispatch report notification"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "dispatch report stop"
      }]
    }]
  }
}
```

Каждый `dispatch report` читает JSON из stdin (контекст от Claude Code),
обогащает данными о машине и проекте, и отправляет POST в Supabase.

### Task Runner (фоновый процесс)

```
dispatch worker start
```

Запускает демон, который:
- Каждые 10 сек проверяет таблицу tasks на наличие задач для этой машины
- Если есть задача со статусом queued и scheduled_at <= now():
  - Проверяет зависимости (depends_on все в статусе done)
  - Меняет статус на running
  - Запускает: `cd {project.repo_path} && claude -p "{task.prompt}" --output-format json`
  - По завершении обновляет задачу: done или error
- Параллельность: настраивается (по умолчанию 1, можно 2-3)

---

## 5. Web App (Next.js)

### Структура страниц

```
src/app/
├── (auth)/
│   ├── login/page.tsx
│   └── register/page.tsx
├── (dashboard)/
│   ├── layout.tsx                -- sidebar с проектами + машинами
│   ├── page.tsx                  -- Overview: все проекты, активные сессии
│   ├── projects/
│   │   ├── page.tsx              -- список проектов
│   │   └── [slug]/
│   │       ├── page.tsx          -- проект: сессии + задачи + таймлайн
│   │       └── tasks/page.tsx    -- очередь задач проекта
│   ├── sessions/
│   │   └── [id]/page.tsx         -- детали сессии: события, лог
│   ├── machines/
│   │   └── page.tsx              -- список машин, статус online/offline
│   └── schedule/
│       └── page.tsx              -- планировщик ночных задач
```

### Ключевые экраны

**Overview (главная)**
- Карточки проектов с прогрессом (как в прототипе дашборда)
- Активные сессии с real-time статусом
- Алерты: ошибки, зависшие сессии, завершённые ночные задачи

**Проект**
- Таймлайн активности за период
- Текущие и завершённые сессии
- Очередь задач (kanban: queued → running → done/error)
- Кнопка "Новая задача" — форма с промптом, выбором машины, расписанием

**Сессия (детали)**
- Поток событий (tool_use, edit, bash) с временными метками
- Ошибки и warnings выделены
- Использование контекста (прогрессбар)
- Общая статистика: токены, длительность, количество tool calls

**Планировщик**
- Создание ночных пакетов: выбрать задачи, порядок, зависимости
- Установить время запуска
- Повторяющиеся задачи (ежедневные прогоны тестов и т.д.)

### Realtime подписки

```typescript
// Подписка на обновления сессий
supabase
  .channel('sessions')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'sessions',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    // обновить UI
  })
  .subscribe()

// Подписка на новые события
supabase
  .channel('events')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'events',
  }, (payload) => {
    // добавить событие в ленту
  })
  .subscribe()
```

---

## 6. Определение статуса сессии

Логика определения статуса на основе событий:

| Событие | Новый статус |
|---------|-------------|
| session_start | active |
| tool_use | active |
| notification (permission) | waiting |
| notification (idle) | idle |
| stop | done |
| stop + error в контексте | error |
| last_event_at > 5 мин назад | stale (Edge Function по cron) |

Edge Function `check-stale-sessions` запускается каждую минуту:

```sql
update sessions
set status = 'stale'
where status in ('active', 'waiting')
  and last_event_at < now() - interval '5 minutes';
```

---

## 7. Аутентификация agent → Supabase

Каждая машина получает `machine_key` при регистрации.
Agent использует его для записи данных:

**Вариант A (рекомендуется): Supabase Edge Function как прокси**

```
Agent → POST /functions/v1/ingest
        Headers: x-machine-key: {key}
        Body: { event_type, session_code, ... }

Edge Function:
  1. Валидирует machine_key → получает user_id, machine_id
  2. Вставляет/обновляет записи в sessions и events
  3. Возвращает 200
```

Это безопаснее, чем давать агенту прямой доступ к Supabase с anon key.

**Вариант B: Service Role Key на машине**

Проще, но менее безопасно. Подходит для MVP, если все машины твои.

---

## 8. MVP — порядок реализации

### Фаза 1: Фундамент (1-2 дня)
- [ ] Supabase проект: таблицы, RLS, миграции
- [ ] Next.js проект: auth, layout, базовый routing
- [ ] Edge Function `ingest` для приёма событий

### Фаза 2: Agent (1 день)
- [ ] CLI-утилита `dispatch` (Node.js / single binary)
- [ ] Команды: init, report, worker start
- [ ] Автонастройка Claude Code hooks

### Фаза 3: Дашборд (2-3 дня)
- [ ] Overview: проекты + активные сессии
- [ ] Страница проекта: сессии + таймлайн
- [ ] Детали сессии: лента событий
- [ ] Realtime подписки

### Фаза 4: Task Manager (1-2 дня)
- [ ] Создание задач через UI
- [ ] Task worker на агенте
- [ ] Ночной планировщик (scheduled_at + cron)

### Фаза 5: Полировка (1-2 дня)
- [ ] Stale session detection
- [ ] Уведомления (Telegram bot?)
- [ ] Фильтры и поиск по истории

**Итого: ~7-10 дней до рабочего MVP**

---

## 9. Будущие возможности

- **Терминал в браузере**: WebSocket relay к tmux-сессиям (как у Marc Nuri)
- **AI-анализ логов**: Claude анализирует ошибки и предлагает решения
- **Метрики эффективности**: токены/задачу, время выполнения, success rate
- **Командная работа**: несколько пользователей, shared проекты
- **Telegram-бот**: статусы, алерты, запуск задач через чат
- **Публичный SaaS**: русскоязычная диспетчерская для AI-агентов
