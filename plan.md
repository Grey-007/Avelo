# Avelo - Feature Roadmap & Plan

Avelo is evolving into a beautiful, minimal, and highly effective productivity tool. Based on the current architecture (calendar-based tasks, timers, timelines, and rich themes), here is a proposed list of new features to elevate the app.

## 1. Timer-to-Task Integration
**Concept:** Currently, the timer and tasks are somewhat separate. This feature will allow you to link a Pomodoro session directly to a specific task.
**Implementation Steps:**
- Add an optional "Link Task" selector in the Timer page.
- Update the `timer_logs` table in the database to store an optional `task_id`.
- Update the Timeline page to show exactly *what* task you were working on during that time block, using the task's tag color for the timeline segment.

## 2. Drag & Drop Task Prioritization
**Concept:** Allow users to easily prioritize tasks for the day by dragging them up and down.
**Implementation Steps:**
- Wrap the task `ListView` in a `ReorderableListView` in the Calendar page.
- Hook up the `onReorder` callback to the existing `TodoDB.instance.reorder` method.
- Add subtle haptic feedback, scale animations, and shadow elevation when dragging a task.

## 3. Recurring Tasks
**Concept:** Automatically generate tasks for daily habits or weekly chores.
**Implementation Steps:**
- Add a `recurrence` rule column to the `todos` table (e.g., "daily", "weekly").
- Update the database logic: when querying tasks for a day, dynamically project recurring tasks that fall on that date.
- Add a recurrence dropdown/picker to the "Add Task" setup dialog.

## 4. Subtasks & Checklists
**Concept:** Break down larger, intimidating tasks into smaller, manageable sub-items.
**Implementation Steps:**
- Create a `subtasks` table linked to a parent `todo.id`.
- Update the task UI to allow expanding a task to see and check off subtasks.
- Show a mini progress bar or indicator (e.g., "2/5") on the main task card.

## 5. Analytics & Insights Dashboard
**Concept:** A dedicated page to visualize productivity trends over time.
**Implementation Steps:**
- Add a new "Insights" or "Stats" tab to the side navigation bar.
- Implement charts (using a library like `fl_chart` or custom painters) to show tasks completed per week.
- Show a visual breakdown (pie chart or bar chart) of time spent per tag (e.g., Work vs. Personal).

## 6. Reminders & Local Notifications
**Concept:** Ping the user when a task is due or when a Pomodoro timer finishes.
**Implementation Steps:**
- Integrate the `flutter_local_notifications` package.
- Add an optional "Due Time" picker to the task setup dialog.
- Schedule a local notification when a time is set, and alert the user when a timer completes.

## 7. Zen / Focus Mode
**Concept:** A distraction-free UI state that hides the sidebar and calendar, showing only the active task and a massive, beautifully animated timer.
**Implementation Steps:**
- Add an "Enter Focus Mode" toggle on the Timer page.
- Smoothly animate the sidebar and calendar out of the screen.
- Maximize the timer and use the active task's tag color to create an ambient, breathing background glow using the glassmorphic theme engine.

---

**Next Steps:**
Please review these ideas! Let me know which features you like the most, and we can prioritize them and start building them one by one.
