# Quality Scanner Dashboard

Web dashboard for visualizing Quality Scanner results.

## Configuration

Copy `.env.local` and adjust as needed:

| Variable | Description | Default |
|----------|-------------|--------|
| `REPORTS_PATH` | Path to the reports directory (relative or absolute) | `../reports` |
| `NEXT_PUBLIC_SONAR_URL` | Public SonarQube URL (for clickable links) | `http://localhost:9000` |
| `PORT` | Dashboard port | `3000` |

## Running

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Features

- **History** — sidebar with scans grouped by date
- **Summary** — cards with passed/failed/warnings/skipped counts
- **Tools** — expandable/collapsible cards with per-tool details
- **SonarQube** — metrics, quality gate conditions, and direct link to the SQ dashboard
- **Jest** — coverage by category and by file, failing tests
- **ESLint** — issues grouped by rule with occurrences

