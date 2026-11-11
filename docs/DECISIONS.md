# Architectural & Engineering Decisions (ADR)
**Project**: UET Societies Hub  
**Role**: Senior Full-Stack Engineer & QA Lead  
**Status**: Approved & Adopted  
**Last Updated**: 2026-11-11  

---

## ADR-01: Deep-Linking & SPA Routing for GitHub Pages
* **Context**: GitHub Pages is a static file server with no native server-side rewrites for Single Page Applications (SPAs). The existing application held active tab and search states in transient React component state, causing page refreshes to lose state, breaking browser back/forward navigation, and making deep links unshareable.
* **Decision**: 
  1. Synchronize application state with URL query parameters (`?tab=societies&q=acm&category=Technical`) and hash anchors using standard HTML5 `window.history.pushState` and `window.addEventListener('popstate')`.
  2. Deploy a `404.html` in `web/public/` that intercepts sub-path hits on GitHub Pages and routes them cleanly back to `/uet-societies-hub/?tab=...`.
* **Consequences**: Enables deep linking, back/forward button support, and state preservation on refresh with zero external routing overhead.

---

## ADR-02: Search, Filter & Unicode Normalization Engine
* **Context**: The existing search logic used naive `.includes(searchQuery.toLowerCase())` without trimming whitespace, debouncing rapid inputs, or normalizing Urdu/multilingual Unicode text.
* **Decision**:
  1. Implement a custom `useSearchFilter` hook utilizing `useDebounce` (300ms) to ensure smooth 60fps typing on mobile and low-power devices.
  2. Normalize all search inputs and target fields using `String.prototype.normalize('NFC')` and trim extraneous whitespace before comparison.
  3. Support multi-field tokenized matching (society name, category, department keywords, description tags).
  4. Provide an interactive empty state featuring a "Clear Search" / "Reset All Filters" button.
* **Consequences**: Immediate responsiveness, resistance to whitespace/casing bugs, and complete support for Unicode campus naming.

---

## ADR-03: Strict Timezone Standardization (`Asia/Karachi` PKT / UTC+5)
* **Context**: Event start times, end times, and recruitment deadlines were formatted using `toLocaleDateString()` without specifying a timezone. This caused dates to display incorrectly for students accessing the site with UTC system clocks or from abroad.
* **Decision**: Centralize all date and time rendering through an explicit utility `formatPKTDate(date, options)` with `timeZone: 'Asia/Karachi'`.
* **Consequences**: Guarantees consistent, accurate event timelines and recruitment countdowns across all student devices.

---

## ADR-04: Resilient Fetch Handling with User-Facing Error States
* **Context**: Component data fetch catch blocks merely logged errors to `console.error` and toggled `loading = false`, presenting students with blank feeds and no feedback during network drops or API rate-limiting.
* **Decision**:
  1. Equip feeds and sections with explicit `error` state tracking.
  2. Display accessible Error Banner components with a descriptive message and an interactive "Try Again" retry trigger.
* **Consequences**: Eliminates silent failures and gives students transparent status during intermittent connectivity.

---

## ADR-05: Editorial Campus-Tech Redesign Architecture
* **Context**: The existing user interface relies on generic dark-slate boxes, dark rectangular skeletons, and lacks dynamic visual hierarchy, brand personality, and motion.
* **Decision**:
  1. **Aesthetic Direction**: Modern Editorial Campus-Tech. Bold, disciplined typography (`Plus Jakarta Sans` / `Inter` paired with monospace details for roll numbers and deadlines), deep neutral carbon base (`#090d16` / `#0d1117`), and electric campus emerald (`#10b981`) + cyan (`#06b6d4`) accents. No generic purple blobs or muddy glassmorphism.
  2. **Motion System**: Staggered entrance animations, smooth hover lift & tilt on society cards, animated stats counter for registered students/events/societies, infinite logo marquee ticker for official campus societies, shrink-on-scroll sticky navigation, and animated recruitment deadline badges.
  3. **Accessibility Guard**: Wrap all animation pipelines in `@media (prefers-reduced-motion: reduce)` to respect vestibular motion preferences.
* **Consequences**: Transforms the site into an authentic, high-impact institutional tech portal while preserving lightweight bundle size and sub-second load times.

---

## ADR-06: Accessibility (WCAG 2.1 AA) & Focus Management
* **Context**: Multiple elements lacked sufficient color contrast (`slate-500` on `slate-950`), modals had no keyboard focus trapping or `Escape` key dismissal, icon-only buttons lacked `aria-label`, and the document lacked an `<h1>` heading.
* **Decision**:
  1. Audit and adjust all text color tokens to ensure at least 4.5:1 contrast for normal text and 3:1 for large text.
  2. Implement an accessible Modal Dialog wrapper with focus trapping, `Escape` key handling, backdrop click, and automatic restoration of focus to the triggering element.
  3. Ensure every icon button has a descriptive `aria-label`.
  4. Establish semantic heading hierarchy starting with a primary `<h1>` on every view.
* **Consequences**: Complete WCAG 2.1 Level AA compliance, making the portal fully usable via screen readers and keyboard navigation.

---

## ADR-07: Testing Framework Selection (Vitest + Playwright)
* **Context**: The repository had zero automated test runners configured in `package.json`.
* **Decision**:
  1. Adopt **Vitest** for unit and integration testing of search/filter algorithms, date parsing, form validation, and URL query synchronization.
  2. Adopt **Playwright** for end-to-end multi-viewport browser testing (360px mobile, 768px tablet, 1440px desktop), verifying responsive layouts, modal flows, and accessibility trees.
* **Consequences**: Rigorous automated regression protection for all search, filter, and user journey workflows.
