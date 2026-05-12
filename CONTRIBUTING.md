# Contributing & Development Agreement
### Read at 2:14 AM — Apple Developer Academy

---

## 1. Team Members & Roles

| Name | Role | Main Responsibility |
|------|------|-------------------|
| Joshua | Domain Expert | Coordinate gameplay and domain direction |
| Dwinda | Tech | Story logic & Git management |
| Stefanie | Tech | Xcode project setup & architecture |
| Steve | Tech | Feature development |
| Nicole | Designer | Design assets & UI |

---

## 2. Project Goal

Create an interactive narrative mobile game with a chat-based interface that delivers emotional storytelling through meaningful player choices and immersive system interactions.

---

## 3. Team Agreement

We agree to:
1. Respect each member's role and contribution
2. Communicate clearly and honestly
3. Support each other during blockers or difficulties
4. Maintain professionalism during collaboration
5. Prioritize project progress over personal ego
6. Give constructive feedback respectfully
7. Be responsible for assigned tasks and deadlines

---

## 4. Responsibility & Ownership

Each member is responsible for:
1. Completing assigned tasks on time
2. Updating task progress in the Kanban board
3. Informing the team early if blocked
4. Asking for help when necessary
5. Participating in discussions and reviews

> *"You don't have to do it alone, but you're the one who ensures it gets done."*

---

## 5. Communication Rules

**Main Platform:** iMessage

**Daily Check-in** (following the Academy's daily alignment practice):
1. What did you do yesterday?
2. What is your current obstacle?
3. What are you focusing on today?

---

## 6. Task Management Workflow

The team uses **Jira** with the following Kanban workflow:

| Status | Description |
|--------|-------------|
| Backlog | Tasks identified but not started |
| To Do | Tasks ready to be worked on |
| In Progress | Currently being developed |
| Review | Awaiting PR review |
| Done | Merged and completed |

Tasks should be broken down into:
- Main Tasks
- Subtasks
- Estimated Duration
- Assigned Owner

Following the development breakdown process: **Game Statement → Task → Subtask → Ownership**

---

## 7. Scope Management

The team agrees to:
1. Prioritize core gameplay first
2. Reduce scope if timeline becomes unrealistic
3. Avoid unnecessary feature additions without team approval
4. Focus on achieving milestone deliverables

**Key Milestones:**
1. Lo-Fi Prototype
2. Hi-Fi Prototype
3. In Progress Playable
4. Playable Game
5. Final Presentation

---

## 8. Attendance & Participation

Members are expected to:
1. Attend all scheduled team meetings
2. Inform the team in advance if unable to attend
3. Actively participate in discussions and decisions
4. Complete assigned work before review sessions

---

## 9. File & Version Management

### ⚠️ Most Important Rule

> **Only one person is allowed to change the Xcode project structure** (`project.pbxproj`)
>
> Adding/removing files, folders, or targets in the Xcode Navigator modifies this file. If more than one person does this simultaneously, it will cause conflicts that are very difficult to resolve. Always discuss with the team before changing the project structure!

### Branch Strategy

Each feature is worked on in a separate branch, collected in `dev`, then merged to `main` only when stable.

| Branch | Purpose |
|--------|---------|
| `main` | Final stable version. **Never push directly here!** Only updated for demo/submission. |
| `dev` | Main development branch. All features are merged here first. |
| `feature/feature-name` | Branch for new features |
| `fix/bug-name` | Branch for bug fixes |

**Active feature branches:**
```
feature/narrative-engine
feature/alex-ai-foundation
feature/denial-scoring
feature/system-feedback
feature/asset-triggered
feature/notifications
```

### Daily Workflow

```
1. Create a new branch from dev (not main!)
   git checkout dev
   git pull
   git checkout -b feature/your-feature-name

2. Work on your feature, commit regularly

3. Before submitting a PR, merge dev into your branch first
   git checkout dev
   git pull
   git checkout feature/your-feature-name
   git merge dev
   → Resolve any conflicts locally, then test

4. Push your branch to GitHub
   git push origin feature/your-feature-name

5. Create a Pull Request to dev on GitHub (not to main!)
```

> Merge `dev` into `main` only when all features for a milestone are done and tested — before a demo or Academy submission.

### Semantic Commit Message

Format: `type: short description (< 50 characters)`

| Type | When to use | Example |
|------|-------------|---------|
| `feat` | Adding or removing a feature | `feat: add denial score logic` |
| `fix` | Fixing a bug | `fix: handle nil chat scene` |
| `docs` | Updating documentation | `docs: update README` |
| `style` | Code cleanup without logic changes | `style: reorder imports in GameManager` |
| `chore` | Installing new dependencies | `chore: add SpriteKit audio package` |
| `refactor` | Same output, different approach | `refactor: simplify denial level calculation` |

**Tips:**
- Use imperative tone: `add`, `fix`, `update` — not `added`, `fixed`
- One commit = one idea
- Avoid meaningless messages: `update`, `fix`, `done`, `wip`

### Pull Request Format

```markdown
## What
- (What did you build or change?)

## Why
- (Why is this change needed?)

## How
- (How does it work?)

## Testing
- (How should the reviewer test this?)

## Screenshots (optional)

## Anything Else?
(Risks, notes, or anything the reviewer should know)
```

**Tips:**
- Keep PRs small — reviewable in 5–15 minutes
- Explain "why", not just "what"
- Mention affected areas and risks
- Request at least 1 team member to review before merging

---

Happy coding! 🚀
