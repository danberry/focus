# Focus · Repository Detail — Implementation Plan

**Surface:** `/repos/:org/:repo` (desktop) + Repos tab in iOS shell
**Designs:** `Focus Repository.html` · the dossier, two viewports
**Skin:** reuses `briefing-hifi.css` — no new tokens, no new fonts
**Status:** ready to build

---

## 0 · TL;DR for the engineer

You are building **one page** that shows the activity, pulls, people, health and release history of a single repository. Two viewports (desktop ≥ 1024px, mobile < 1024px) sharing one data layer and one component library. No new design tokens. No new fonts. Five sections. Everything is a list, a chart, or a card — no verdicts, no AI summaries, no tooltips required for v1.

Build in this order:

1. Data layer + types (½ day)
2. Shared chart primitives — promote from `repo-hifi.jsx` (1 day)
3. Page shell: chrome, hero, KPI strip, tabs (1 day)
4. Five sections, desktop (2 days)
5. Mobile adaptation (1 day)
6. Polish + a11y + empty states (1 day)

**Total estimate: 6.5 dev-days for one engineer.**

---

## 1 · Routes & data

### 1.1 Route

```
GET  /repos/:org/:repo                   # the dossier
GET  /repos/:org/:repo?tab=pulls         # tab deep-links (decorative for v1)
GET  /repos/:org/:repo?tab=people
GET  /repos/:org/:repo?tab=security
```

Tabs are decorative in v1 — they all render the dossier and just scroll-anchor to the matching `<section id="…">`. Wire real tab routes in v2.

### 1.2 Data sources (single page-level loader)

One server loader hydrates the page in a single round-trip. Underneath it fans out to five upstream calls and merges the results.

| Section          | Upstream                          | Cache    |
|------------------|-----------------------------------|----------|
| Repo metadata    | GitHub `GET /repos/{org}/{repo}`  | 5 min    |
| Activity heatmap | GitHub `GET /repos/.../stats/commit_activity` | 1 hour   |
| PR velocity      | Internal warehouse · `pr_merged_daily` | 15 min |
| Open PRs (list)  | GitHub `GET /repos/.../pulls?state=open` | 2 min  |
| CI runs · 7d     | GitHub `GET /repos/.../actions/runs` | 5 min  |
| Contributors     | Internal warehouse · `contrib_30d` | 1 hour |
| Hot files        | Internal warehouse · `file_churn_30d` | 1 hour |
| Security alerts  | GitHub `GET /repos/.../dependabot/alerts` + code-scanning | 5 min |
| Branches         | GitHub `GET /repos/.../branches` + `compare` | 5 min |
| Releases         | GitHub `GET /repos/.../releases?per_page=10` | 15 min |

Failures **degrade**, do not 500: if Dependabot returns 403, the security card renders the empty state; if the warehouse is down, velocity falls back to the GitHub stats endpoint with reduced fidelity.

### 1.3 TypeScript shape

```ts
type RepoDetail = {
  org: string;
  name: string;
  description: string;
  visibility: 'public' | 'private' | 'internal';
  defaultBranch: string;
  size: string;            // pre-formatted "24.6 MB"
  langs: { l: string; v: number; color: string }[];

  lastRelease: { v: string; when: string };           // when = "2 days ago"
  lastDeploy:  { env: string; when: string; status: 'pass' | 'fail' };

  kpi: {
    mergedWeek: { v: number; deltaPct: number; spark: number[] };
    openPrs:    { v: number; staleCount: number; spark: number[] };
    openIssues: { v: number; closed7d: number; spark: number[] };
    security:   { v: number; critical: number; spark: number[] };
    ci:         { passPct: number; runs7d: number; spark: number[] };
    contributors30d: number;
  };

  activity:    { weeks: number; cells: number[] };    // 7 × weeks, value 0..4
  velocity:    number[];                              // length 16, weekly
  mergedRecent: { l: string; v: number }[];           // 7 entries Mon..Sun
  ciRuns7d:    { l: string; v: number }[];            // 7 entries Mon..Sun

  openPrs: PR[];
  contributors: Contributor[];
  hotFiles: HotFile[];
  alerts: { critical: number; high: number; moderate: number; low: number; total: number };
  alertItems: Alert[];
  branches: Branch[];
  releases: Release[];
};
```

(Complete type definitions live in `types/repo-detail.ts` — write them up front; the components fall out of the types.)

---

## 2 · Component inventory

Promote everything currently in `repo-hifi.jsx` from prototype scope to a shared module. Same names, no API changes — the existing JSX is a 1:1 spec.

### 2.1 Primitives (reuse from briefing-hifi.css)

These already exist. Don't reimplement:

```
.card                 .chip ink|ring|red|blue|green|yellow|purple
.btn ink|ghost|sm     .av sm|lg
.serif  .mono  .eyebrow  .num
.row .col .between .gap-N
.u-red .u-blue .u-green .u-yellow .u-purple
```

### 2.2 Charts (promote from `repo-hifi.jsx`)

| Component   | API                                                                  | Lines today |
|-------------|----------------------------------------------------------------------|-------------|
| `Area`      | `vals: number[], height?, color?, fill?`                             | ~16         |
| `Bars`      | `data: {l, v, accent?}[], height?, accentColor?, baseColor?, label?` | ~18         |
| `Heatmap`   | `weeks?, accent?, cells?: number[]` (0..4)                           | ~24         |
| `Donut`     | `slices, total, label?, size?, thickness?`                           | ~28         |
| `Stack`     | `segs: {v, color}[], height?`                                        | ~10         |
| `Sparkline` | already on Briefing as `<Spark>` — keep both names as aliases        | —           |

Move them to `src/charts/index.tsx` and export from one barrel. Add **one** prop change: every chart accepts `aria-label` and renders an SR-only `<span>` underneath summarizing the values.

### 2.3 Page-level components (new)

```
<RepoChrome />                    top bar with breadcrumb, search, profile
<RepoHero repo />                 serif name + description + chip cluster + at-a-glance rail
<RepoKpi kpi />                   6-up strip (desktop) / 2x2 grid (mobile)
<RepoTabs active />               horizontal scrollable on mobile

<RepoSection num title subtitle action>…</RepoSection>
<RepoCard num title subtitle footer tone>…</RepoCard>

<CardActivity26w cells />
<CardVelocity vals />
<CardOpenPRs prs />
<CardMergedRecent data />
<CardCI data />
<CardContributors people />
<CardHotFiles files />
<CardSecurity alerts />
<CardAlertList items />
<CardBranches branches />
<CardReleases rels />
```

Each `Card*` is a thin wrapper over `<RepoCard>` that takes typed data and renders chart + footer. Everything is presentational — no fetching inside cards.

---

## 3 · Layout spec

### 3.1 Desktop (≥ 1024px) — total height ~3680px scrollable

```
─────────────────────────────────────────────────  border-bottom
  RepoChrome                                        56px tall
─────────────────────────────────────────────────
  RepoHero                                          ~360px tall
    ├─ left: name + desc + chip cluster
    └─ right: 320px "At a glance" rail (paper-2 bg)
─────────────────────────────────────────────────
  RepoTabs (Overview · Pulls · Issues · …)          50px tall
─────────────────────────────────────────────────
  RepoKpi  6 columns, 1px dividers                  ~120px tall
─────────────────────────────────────────────────
  § 01  Activity                              2-col
        ├─ CardActivity26w  (heatmap)
        └─ CardVelocity     (area chart)
─────────────────────────────────────────────────
  § 02  Pull requests                         2-col + full-width
        ├─ CardOpenPRs
        ├─ CardMergedRecent
        └─ CardCI                  (full bleed)
─────────────────────────────────────────────────
  § 03  People                                2-col
        ├─ CardContributors
        └─ CardHotFiles
─────────────────────────────────────────────────
  § 04  Health & security                     2-col + full-width
        ├─ CardSecurity
        ├─ CardAlertList   (top 5 critical)
        └─ CardActivity26w (alert intake)    (full bleed)
─────────────────────────────────────────────────
  § 05  Branches & releases                   2-col
        ├─ CardBranches
        └─ CardReleases
─────────────────────────────────────────────────
  Footer · "Auto-synced · last refresh 8m ago"
```

- Page max-width: **none**. Hero, KPI and section content are gutter-padded `0 56px`.
- Section grid: `display: grid; grid-template-columns: 1fr 1fr; gap: 20px;`
- Full-bleed cards inside a section: `grid-column: 1 / -1;`

### 3.2 Mobile (< 1024px) — total height ~3600px

- Chrome collapses: hide search, hide right-side chips. Keep breadcrumb (back chevron + repo name) and avatar.
- Hero serif drops to **38pt**, chip cluster wraps to two rows.
- The desktop "At a glance" rail moves into the chip cluster + the latest-release strip under § 05.
- KPI strip becomes a **2 × 2 grid** of the four most actionable numbers: Merged 7d · Open PRs · Critical alerts · CI pass.
- Section `<RepoCard>` children stack full-width.
- Branches and releases become tap-target rows; long branch names truncate with ellipsis on the left, ahead/behind chips stay right-aligned.
- Tab bar matches the existing Briefing-mobile shell with **Repos** tab active. No new navigation primitives.

### 3.3 Breakpoints

```css
/* one breakpoint, no in-between */
@media (max-width: 1023px) { /* mobile shell */ }
```

Resist tablet-specific layout for v1. iPad lands on the desktop layout.

---

## 4 · Section-by-section build notes

### § 01 Activity

- **Heatmap** is 26 weeks × 7 days. Color levels 0..4 mapped to the existing `--rule-2` → `--ink` ramp.
- **Velocity** is 16 weekly points, area chart with last point dot.
- Both cards are equal-width.
- Empty state: "No commits in the last 26 weeks" — single line, `--ink-3`.

### § 02 Pull requests

- **CardOpenPRs**: max 5 rows, dashed dividers, columns `#id · title (truncate) · avatar · age · CI chip`.
  - CI chip is `green | red | ring`, never `yellow`.
  - Rows are clickable, navigate to `/repos/.../pull/:n`.
- **CardMergedRecent**: bar chart by weekday; weekend bars are visibly shorter, no special accent.
- **CardCI**: 7-day bar chart, footer shows "{failed} failed · {runs} runs". Full-bleed.
- Empty PRs state: "No open pull requests" + secondary "0 closed in the last 7 days" if relevant.

### § 03 People

- **CardContributors**: top 6 by merged-PR count, 30d window. Avatar · name · role chip · bar · count.
- **CardHotFiles**: top 6 paths by churn, 30d. Mono path (truncate left, keep filename) · sparkline of edits · count.
- Empty state: "No contributor activity in the last 30 days."

### § 04 Health & security

- **CardSecurity**: tone="red". Headline number, stacked horizontal bar of critical/high/moderate/low, four columns of severity counts.
- **CardAlertList**: top 5 by severity then age. Severity dot · CVE id · package · age · "Triage →".
- **CardAlertIntake** (full-bleed): a second heatmap, same primitive, alerts opened per day. Reuse `<Heatmap cells />`, just pass alert-intake cells.
- Empty state: "No open security alerts" — show as a quiet `card.green` with the green check chip.

### § 05 Branches & releases

- **CardBranches**: 6 rows, branch chip (tone-coded: ink=default, blue=staging, yellow=behind, red=stale), status, ahead/behind (↑n / ↓n), age.
- **CardReleases**: 5 most recent. Tag · body (one line) · age. Minor releases (`x.y.0`) get the blue tone.
- Empty state for releases: "No releases yet" + secondary "Cadence will appear after the first tag."

---

## 5 · Acceptance criteria

A v1 ships when, on a fully-loaded `payments-api`:

- [ ] Page hydrates in ≤ 800ms p50 from a warm cache; ≤ 2.5s p95 cold.
- [ ] All 11 cards have real data — no skeletons remain after hydration.
- [ ] Every chart announces its summary to a screen reader (axe shows 0 critical issues).
- [ ] Resize from 1280 → 390 reflows cleanly with no horizontal scroll at any width.
- [ ] Tab bar deep-link `?tab=security` scrolls § 04 into view on load.
- [ ] PR row click navigates to the GitHub PR in a new tab.
- [ ] "Open in GitHub ↗" button in chrome navigates to `https://github.com/{org}/{repo}`.
- [ ] Empty states render for all 11 cards when their data is `[]` or `null`.
- [ ] No 500s when Dependabot is unavailable — security card shows the degraded state.

### Performance budget

- Initial JS bundle for this route: **≤ 60 KB gzipped** (components + charts, excluding shared shell).
- Largest image on the page: zero — all charts are SVG.
- LCP element: the serif H1 in `<RepoHero>`. Pre-render server-side.

### A11y

- Color is never the sole signal: every red chip / row / number has a textual label ("3 critical").
- Focus order: Chrome → Tabs → KPI (skip) → §01 first card → §01 second card → … → §05 last card.
- Heatmap and donut both expose `role="img"` + `aria-label` summary.

---

## 6 · What to skip in v1

These are fair asks but explicitly out of scope. Don't build them now:

- Live tab routing (use scroll-anchors)
- Filter / date-range controls on individual cards
- Drilldown pages (`/repos/.../security`, `/repos/.../branches/:b`)
- Tweaks panel
- Dark mode (already inherits — verify visually, don't tune)
- Notification subscriptions
- Comparison view (this repo vs another)

File these in `Repository v2` once v1 is in production.

---

## 7 · Tracker breakdown

| # | Ticket                                              | Est | Owner |
|---|-----------------------------------------------------|-----|-------|
| 1 | Page-level loader + `RepoDetail` type               | 0.5d|       |
| 2 | Promote charts to `src/charts` + a11y labels        | 1.0d|       |
| 3 | `<RepoChrome>` `<RepoHero>` `<RepoKpi>` `<RepoTabs>`| 1.0d|       |
| 4 | § 01 Activity (2 cards)                             | 0.5d|       |
| 5 | § 02 Pulls (3 cards)                                | 0.5d|       |
| 6 | § 03 People (2 cards)                               | 0.5d|       |
| 7 | § 04 Health & security (3 cards)                    | 0.5d|       |
| 8 | § 05 Branches & releases (2 cards)                  | 0.5d|       |
| 9 | Mobile shell + tab integration                      | 1.0d|       |
|10 | Empty states + a11y pass + perf check               | 1.0d|       |

**Total: 6.5 dev-days · 1 engineer · 1 sprint.**

---

## 8 · Open questions for the PM

1. **Source of truth for "stale".** Reports calls a PR stale at > 7d idle; do we use the same threshold here, or per-repo override?
2. **CI pass target.** Hard-coded 95% in the design — is this per-repo, per-org, or global?
3. **Hot files privacy.** Do private repos surface file paths in the People section, or just "{n} files churned"?
4. **Release cadence stat.** "1 per 3.2d" is computed from the last 38 releases — is that the right window or do we cap at last 90d?
5. **Tab persistence.** Does the active tab live in URL, localStorage, or session?

Get these answered before ticket #1 lands.

