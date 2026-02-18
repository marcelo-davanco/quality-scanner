'use client';

import { useEffect, useState, useCallback } from 'react';
import {
  Shield, FileCode, AlertTriangle, CheckCircle2, XCircle,
  ChevronDown, ChevronRight, ExternalLink, Clock, Calendar,
  Bug, Lock, Trash2, TestTube, Eye, PackageSearch, RefreshCw,
  SkipForward
} from 'lucide-react';

/* ------------------------------------------------------------------ */
/* Types                                                               */
/* ------------------------------------------------------------------ */
interface Scan {
  date: string;
  scanId: string;
  project: string;
  gateStatus: string;
  duration: number;
  errors: number;
  warnings: number;
  timestamp: string;
}

interface ToolReport {
  tool: string;
  status: string;
  summary: string;
  timestamp: string;
  details: any; // eslint-disable-line @typescript-eslint/no-explicit-any
}

/* eslint-disable @typescript-eslint/no-explicit-any */

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */
const STATUS_CONFIG: Record<string, { color: string; bg: string; icon: React.ReactNode; label: string }> = {
  pass: { color: 'text-emerald-400', bg: 'bg-emerald-500/10 border-emerald-500/20', icon: <CheckCircle2 size={18} />, label: 'Passed' },
  fail: { color: 'text-red-400', bg: 'bg-red-500/10 border-red-500/20', icon: <XCircle size={18} />, label: 'Failed' },
  warn: { color: 'text-amber-400', bg: 'bg-amber-500/10 border-amber-500/20', icon: <AlertTriangle size={18} />, label: 'Warning' },
  skip: { color: 'text-slate-500', bg: 'bg-slate-500/10 border-slate-500/20', icon: <SkipForward size={18} />, label: 'Skipped' },
};

const TOOL_ICONS: Record<string, React.ReactNode> = {
  gitleaks: <Lock size={18} />,
  typescript: <FileCode size={18} />,
  eslint: <Eye size={18} />,
  prettier: <FileCode size={18} />,
  audit: <Shield size={18} />,
  knip: <Trash2 size={18} />,
  jest: <TestTube size={18} />,
  sonarqube: <Bug size={18} />,
};

const TOOL_LABELS: Record<string, string> = {
  gitleaks: 'Gitleaks',
  typescript: 'TypeScript',
  eslint: 'ESLint',
  prettier: 'Prettier',
  audit: 'npm audit',
  knip: 'Knip',
  jest: 'Jest',
  sonarqube: 'SonarQube',
};

const GATE_COLORS: Record<string, string> = {
  PASSED: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30',
  PASSED_WITH_WARNINGS: 'text-amber-400 bg-amber-500/10 border-amber-500/30',
  FAILED: 'text-red-400 bg-red-500/10 border-red-500/30',
};

function formatDuration(s: number): string {
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m ${s % 60}s`;
}

const SONAR_PUBLIC_URL = process.env.NEXT_PUBLIC_SONAR_URL || 'http://localhost:9000';

function rewriteSonarUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const pub = new URL(SONAR_PUBLIC_URL);
    parsed.protocol = pub.protocol;
    parsed.hostname = pub.hostname;
    parsed.port = pub.port;
    return parsed.toString();
  } catch {
    return url.replace(/http:\/\/sonarqube:\d+/, SONAR_PUBLIC_URL);
  }
}

/* ------------------------------------------------------------------ */
/* Detail renderers per tool                                           */
/* ------------------------------------------------------------------ */
function SonarQubeDetails({ details }: { details: any }) {
  if (!details || typeof details !== 'object') return null;
  const { metrics, issuesByType, totalIssues, dashboardUrl, conditions } = details;

  return (
    <div className="space-y-4">
      {/* Metrics */}
      {metrics && Object.keys(metrics).length > 0 && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 uppercase mb-2">Metrics</h4>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {Object.entries(metrics).map(([key, val]) => (
              <div key={key} className="bg-slate-800/50 rounded px-3 py-2">
                <div className="text-xs text-slate-500">{key.replace(/_/g, ' ')}</div>
                <div className="text-sm font-mono text-slate-200">{String(val)}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Quality Gate Conditions */}
      {conditions && conditions.length > 0 && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 uppercase mb-2">Quality Gate Conditions</h4>
          <div className="space-y-1">
            {conditions.map((c: any, i: number) => (
              <div key={i} className={`flex items-center gap-2 text-sm ${c.status === 'OK' ? 'text-emerald-400' : 'text-red-400'}`}>
                {c.status === 'OK' ? <CheckCircle2 size={14} /> : <XCircle size={14} />}
                <span className="text-slate-300">{c.metricKey}</span>
                <span className="text-slate-500">({c.comparator} {c.errorThreshold})</span>
                <span className="font-mono">{c.actualValue}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Issues by type */}
      {issuesByType && Object.keys(issuesByType).length > 0 && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 uppercase mb-2">Issues ({totalIssues})</h4>
          {Object.entries(issuesByType).map(([type, data]: [string, any]) => (
            <CollapsibleSection key={type} title={`${type} (${data.count})`} defaultOpen={false}>
              <div className="space-y-1">
                {data.items?.map((item: any, i: number) => (
                  <div key={i} className="text-xs font-mono text-slate-400 flex gap-2">
                    <span className={`px-1 rounded ${item.severity === 'CRITICAL' ? 'bg-red-900/50 text-red-300' : item.severity === 'MAJOR' ? 'bg-amber-900/50 text-amber-300' : 'bg-slate-700 text-slate-400'}`}>
                      {item.severity}
                    </span>
                    <span className="text-slate-500 truncate max-w-[200px]">{item.component}:{item.line}</span>
                    <span className="text-slate-300 truncate">{item.message}</span>
                  </div>
                ))}
              </div>
            </CollapsibleSection>
          ))}
        </div>
      )}

      {/* Dashboard link */}
      {dashboardUrl && (
        <a href={rewriteSonarUrl(dashboardUrl)} target="_blank" rel="noopener noreferrer"
          className="inline-flex items-center gap-2 text-sm text-blue-400 hover:text-blue-300 transition-colors">
          <ExternalLink size={14} /> Open SonarQube Dashboard
        </a>
      )}
    </div>
  );
}

function JestDetails({ details }: { details: any }) {
  if (!details || typeof details !== 'object') return null;
  const { passed, failed, total, coverage, failures, files } = details;

  return (
    <div className="space-y-4">
      {/* Summary */}
      <div className="flex gap-4 text-sm">
        <span className="text-emerald-400">{passed} passing</span>
        {failed > 0 && <span className="text-red-400">{failed} failing</span>}
        <span className="text-slate-500">{total} total</span>
      </div>

      {/* Coverage */}
      {coverage && Object.keys(coverage).length > 0 && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 uppercase mb-2">Coverage</h4>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {['statements', 'branches', 'functions', 'lines'].map(k => {
              const c = coverage[k];
              if (!c) return null;
              const pct = c.pct || 0;
              return (
                <div key={k} className="bg-slate-800/50 rounded px-3 py-2">
                  <div className="text-xs text-slate-500 capitalize">{k}</div>
                  <div className={`text-lg font-mono ${pct >= 80 ? 'text-emerald-400' : pct >= 60 ? 'text-amber-400' : 'text-red-400'}`}>
                    {pct}%
                  </div>
                  <div className="text-xs text-slate-600">{c.covered}/{c.total}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Failing tests */}
      {failures && failures.length > 0 && (
        <CollapsibleSection title={`Failing tests (${failures.length})`} defaultOpen={true}>
          <div className="space-y-2">
            {failures.map((f: any, i: number) => (
              <div key={i} className="bg-red-900/20 rounded p-2">
                <div className="text-sm text-red-300 font-medium">{f.test}</div>
                <pre className="text-xs text-red-400/70 mt-1 whitespace-pre-wrap max-h-32 overflow-auto">{f.message}</pre>
              </div>
            ))}
          </div>
        </CollapsibleSection>
      )}

      {/* Coverage by file */}
      {files && files.length > 0 && (
        <CollapsibleSection title={`Coverage by file (${files.length})`} defaultOpen={false}>
          <div className="space-y-1">
            {files.map((f: any, i: number) => (
              <div key={i} className="text-xs font-mono text-slate-400 flex gap-3">
                <span className="text-slate-300 truncate flex-1">{f.file}</span>
                <span>S:{f.statements}</span>
                <span>B:{f.branches}</span>
                <span>F:{f.functions}</span>
              </div>
            ))}
          </div>
        </CollapsibleSection>
      )}
    </div>
  );
}

function EslintDetails({ details }: { details: any }) {
  if (!Array.isArray(details) || details.length === 0) return <p className="text-xs text-slate-500">No details</p>;

  return (
    <div className="space-y-2">
      {details.map((rule: any, i: number) => (
        <CollapsibleSection key={i} title={`${rule.rule} (${rule.count})`} defaultOpen={false}>
          <div className="space-y-1">
            {rule.occurrences?.map((o: any, j: number) => (
              <div key={j} className="text-xs font-mono flex gap-2">
                <span className={o.severity === 'error' ? 'text-red-400' : 'text-amber-400'}>{o.severity}</span>
                <span className="text-slate-500">{o.file}:{o.line}</span>
                <span className="text-slate-400 truncate">{o.message}</span>
              </div>
            ))}
          </div>
        </CollapsibleSection>
      ))}
    </div>
  );
}

function GenericDetails({ details }: { details: any }) {
  if (!details) return null;
  if (Array.isArray(details) && details.length === 0) return <p className="text-xs text-slate-500">No details</p>;

  return (
    <div className="space-y-1 max-h-64 overflow-auto">
      {Array.isArray(details) ? details.map((item: any, i: number) => (
        <div key={i} className="text-xs font-mono text-slate-400">
          {Object.entries(item).map(([k, v]) => (
            <span key={k} className="mr-3">
              <span className="text-slate-600">{k}:</span> {String(v)}
            </span>
          ))}
        </div>
      )) : (
        <pre className="text-xs font-mono text-slate-400 whitespace-pre-wrap">{JSON.stringify(details, null, 2)}</pre>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Collapsible Section                                                 */
/* ------------------------------------------------------------------ */
function CollapsibleSection({ title, defaultOpen = false, children }: {
  title: string;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="border border-slate-700/50 rounded">
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-300 hover:bg-slate-800/50 transition-colors"
      >
        {open ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
        {title}
      </button>
      {open && <div className="px-3 pb-3">{children}</div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Tool Card                                                           */
/* ------------------------------------------------------------------ */
function ToolCard({ report }: { report: ToolReport }) {
  const [expanded, setExpanded] = useState(false);
  const cfg = STATUS_CONFIG[report.status] || STATUS_CONFIG.skip;
  const icon = TOOL_ICONS[report.tool] || <PackageSearch size={18} />;
  const label = TOOL_LABELS[report.tool] || report.tool;

  const renderDetails = () => {
    switch (report.tool) {
      case 'sonarqube': return <SonarQubeDetails details={report.details} />;
      case 'jest': return <JestDetails details={report.details} />;
      case 'eslint': return <EslintDetails details={report.details} />;
      default: return <GenericDetails details={report.details} />;
    }
  };

  const hasDetails = report.details && (
    (Array.isArray(report.details) && report.details.length > 0) ||
    (!Array.isArray(report.details) && typeof report.details === 'object' && Object.keys(report.details).length > 0)
  );

  return (
    <div className={`border rounded-lg transition-all ${cfg.bg}`}>
      <button
        onClick={() => hasDetails && setExpanded(!expanded)}
        className={`w-full flex items-center gap-3 px-4 py-3 text-left ${hasDetails ? 'cursor-pointer hover:bg-white/5' : 'cursor-default'}`}
      >
        <span className={cfg.color}>{icon}</span>
        <span className="font-medium text-slate-200 min-w-[100px]">{label}</span>
        <span className={`flex items-center gap-1.5 text-sm ${cfg.color}`}>
          {cfg.icon}
          {report.summary}
        </span>
        <span className="ml-auto">
          {hasDetails && (
            expanded ? <ChevronDown size={16} className="text-slate-500" /> : <ChevronRight size={16} className="text-slate-500" />
          )}
        </span>
      </button>
      {expanded && hasDetails && (
        <div className="px-4 pb-4 border-t border-slate-700/30 pt-3">
          {renderDetails()}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Main Dashboard                                                      */
/* ------------------------------------------------------------------ */
export default function Dashboard() {
  const [scans, setScans] = useState<Scan[]>([]);
  const [selectedScan, setSelectedScan] = useState<Scan | null>(null);
  const [reports, setReports] = useState<Record<string, ToolReport>>({});
  const [loading, setLoading] = useState(true);

  const fetchScans = useCallback(async () => {
    try {
      const res = await fetch('/api/reports');
      const data = await res.json();
      setScans(data.scans || []);
      if (data.scans?.length > 0 && !selectedScan) {
        setSelectedScan(data.scans[0]);
      }
    } catch (e) {
      console.error('Failed to fetch scans:', e);
    } finally {
      setLoading(false);
    }
  }, [selectedScan]);

  const fetchReports = useCallback(async (scan: Scan) => {
    try {
      const res = await fetch(`/api/reports?date=${scan.date}&scanId=${scan.scanId}`);
      const data = await res.json();
      setReports(data);
    } catch (e) {
      console.error('Failed to fetch reports:', e);
    }
  }, []);

  useEffect(() => { fetchScans(); }, [fetchScans]);
  useEffect(() => { if (selectedScan) fetchReports(selectedScan); }, [selectedScan, fetchReports]);

  const toolOrder = ['gitleaks', 'typescript', 'eslint', 'prettier', 'audit', 'knip', 'jest', 'sonarqube'];

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <RefreshCw className="animate-spin text-slate-500" size={32} />
      </div>
    );
  }

  if (scans.length === 0) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 text-slate-500">
        <PackageSearch size={48} />
        <p className="text-lg">No scans found</p>
        <p className="text-sm">Run <code className="bg-slate-800 px-2 py-1 rounded">./scan.sh ./your-project</code> to generate reports</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex">
      {/* Sidebar — History */}
      <aside className="w-72 border-r border-slate-800 bg-slate-900/50 overflow-y-auto flex-shrink-0">
        <div className="p-4 border-b border-slate-800">
          <h1 className="text-lg font-bold text-slate-200 flex items-center gap-2">
            <Shield size={20} className="text-blue-400" />
            Quality Scanner
          </h1>
        </div>

        <div className="p-2">
          {/* Group by date */}
          {Array.from(new Set(scans.map(s => s.date))).map(date => (
            <div key={date} className="mb-3">
              <div className="flex items-center gap-2 px-2 py-1 text-xs font-semibold text-slate-500 uppercase">
                <Calendar size={12} />
                {date}
              </div>
              {scans.filter(s => s.date === date).map(scan => {
                const isSelected = selectedScan?.scanId === scan.scanId;
                const gateColor = scan.gateStatus === 'FAILED' ? 'text-red-400' :
                  scan.gateStatus === 'PASSED_WITH_WARNINGS' ? 'text-amber-400' : 'text-emerald-400';
                return (
                  <button
                    key={scan.scanId}
                    onClick={() => setSelectedScan(scan)}
                    className={`w-full text-left px-3 py-2 rounded-lg mb-1 transition-colors ${isSelected ? 'bg-blue-500/10 border border-blue-500/30' : 'hover:bg-slate-800/50 border border-transparent'
                      }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-slate-300 font-medium truncate">{scan.project}</span>
                      <span className={`text-xs ${gateColor}`}>
                        {scan.gateStatus === 'FAILED' ? '✗' : scan.gateStatus === 'PASSED_WITH_WARNINGS' ? '⚠' : '✓'}
                      </span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-slate-600 mt-0.5">
                      <Clock size={10} />
                      {scan.scanId.replace('_', ' ')}
                      <span>· {formatDuration(scan.duration)}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto">
        {selectedScan && (
          <div className="max-w-4xl mx-auto p-6">
            {/* Header */}
            <div className="mb-6">
              <div className="flex items-center gap-3 mb-2">
                <h2 className="text-2xl font-bold text-slate-100">{selectedScan.project}</h2>
                <span className={`px-3 py-1 rounded-full text-sm font-medium border ${GATE_COLORS[selectedScan.gateStatus] || 'text-slate-400 bg-slate-800 border-slate-700'}`}>
                  {selectedScan.gateStatus.replace(/_/g, ' ')}
                </span>
              </div>
              <div className="flex items-center gap-4 text-sm text-slate-500">
                <span className="flex items-center gap-1"><Calendar size={14} /> {selectedScan.date}</span>
                <span className="flex items-center gap-1"><Clock size={14} /> {formatDuration(selectedScan.duration)}</span>
                {selectedScan.errors > 0 && <span className="text-red-400">{selectedScan.errors} error(s)</span>}
                {selectedScan.warnings > 0 && <span className="text-amber-400">{selectedScan.warnings} warning(s)</span>}
              </div>
            </div>

            {/* Summary cards */}
            <div className="grid grid-cols-4 gap-3 mb-6">
              {(() => {
                const counts = { pass: 0, fail: 0, warn: 0, skip: 0 };
                toolOrder.forEach(t => {
                  const r = reports[t];
                  if (r && r.status) counts[r.status as keyof typeof counts] = (counts[r.status as keyof typeof counts] || 0) + 1;
                });
                return [
                  { label: 'Passed', count: counts.pass, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
                  { label: 'Failed', count: counts.fail, color: 'text-red-400', bg: 'bg-red-500/10' },
                  { label: 'Warnings', count: counts.warn, color: 'text-amber-400', bg: 'bg-amber-500/10' },
                  { label: 'Skipped', count: counts.skip, color: 'text-slate-500', bg: 'bg-slate-500/10' },
                ].map(({ label, count, color, bg }) => (
                  <div key={label} className={`${bg} rounded-lg p-3 text-center border border-slate-700/30`}>
                    <div className={`text-2xl font-bold ${color}`}>{count}</div>
                    <div className="text-xs text-slate-500">{label}</div>
                  </div>
                ));
              })()}
            </div>

            {/* Tool reports */}
            <div className="space-y-2">
              {toolOrder.map(tool => {
                const report = reports[tool];
                if (!report) return null;
                return <ToolCard key={tool} report={report} />;
              })}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
