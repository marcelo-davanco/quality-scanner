import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

const REPORTS_DIR = path.resolve(
  process.cwd(),
  process.env.REPORTS_PATH || '../reports'
);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const scanId = searchParams.get('scanId');
  const date = searchParams.get('date');

  try {
    if (scanId && date) {
      // Return reports for a specific scan
      const scanDir = path.join(REPORTS_DIR, date, scanId);
      if (!fs.existsSync(scanDir)) {
        return NextResponse.json({ error: 'Scan not found' }, { status: 404 });
      }

      const files = fs.readdirSync(scanDir).filter(f => f.endsWith('.json'));
      const reports: Record<string, unknown> = {};
      for (const file of files) {
        const name = file.replace('.json', '');
        const content = fs.readFileSync(path.join(scanDir, file), 'utf-8');
        try {
          reports[name] = JSON.parse(content);
        } catch {
          reports[name] = { error: 'Invalid JSON', raw: content.slice(0, 500) };
        }
      }
      return NextResponse.json(reports);
    }

    // List all available scans
    if (!fs.existsSync(REPORTS_DIR)) {
      return NextResponse.json({ scans: [] });
    }

    const scans: Array<{
      date: string;
      scanId: string;
      project: string;
      gateStatus: string;
      duration: number;
      errors: number;
      warnings: number;
      timestamp: string;
    }> = [];

    const dates = fs.readdirSync(REPORTS_DIR)
      .filter(d => fs.statSync(path.join(REPORTS_DIR, d)).isDirectory())
      .sort()
      .reverse();

    for (const date of dates) {
      const dateDir = path.join(REPORTS_DIR, date);
      const scanIds = fs.readdirSync(dateDir)
        .filter(d => fs.statSync(path.join(dateDir, d)).isDirectory())
        .sort()
        .reverse();

      for (const scanId of scanIds) {
        const summaryPath = path.join(dateDir, scanId, 'summary.json');
        if (fs.existsSync(summaryPath)) {
          try {
            const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf-8'));
            scans.push({
              date,
              scanId,
              project: summary.project || 'unknown',
              gateStatus: summary.gateStatus || 'UNKNOWN',
              duration: summary.duration || 0,
              errors: summary.errors || 0,
              warnings: summary.warnings || 0,
              timestamp: summary.timestamp || '',
            });
          } catch {
            // skip invalid summaries
          }
        }
      }
    }

    return NextResponse.json({ scans });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 500 });
  }
}
