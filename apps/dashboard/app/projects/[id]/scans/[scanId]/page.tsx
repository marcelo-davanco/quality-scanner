'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft, Clock, CheckCircle2, XCircle, AlertTriangle,
  RefreshCw, SkipForward, ChevronDown, ChevronRight,
  Shield, FileCode, Lock, Eye, Trash2, TestTube, Bug,
  PackageSearch, ExternalLink, Calendar, GitBranch
} from 'lucide-react';
import type { Scan, PhaseResult } from '../../../../../lib/api';

/* eslint-disable @typescript-eslint/no-explicit-any */

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';
const SONAR_PUBLIC_URL = process.env.NEXT_PUBLIC_SONAR_URL || 'http://localhost:9000';

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
  gitleaks: <Lock size={18} />, typescript: <FileCode size={18} />,
  eslint: <Eye size={18} />, prettier: <FileCode size={18} />,
  audit: <Shield size={18} />, knip: <Trash2 size={18} />,
  jest: <TestTube size={18} />, sonarqube: <Bug size={18} />,
  'api-lint': <FileCode size={18} />, 'infra-scan': <Shield size={18} />,
};

const TOOL_LABELS: Record<string, string> = {
  gitleaks: 'Gitleaks', typescript: 'TypeScript', eslint: 'ESLint',
  prettier: 'Prettier', audit: 'npm audit', knip: 'Knip',
  jest: 'Jest', sonarqube: 'SonarQube',
  'api-lint': 'API Lint', 'infra-scan': 'Infra Scan',
};

const SCAN_STATUS_BADGE: Record<string, { color: string; label: string }> = {
  passed: { color: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30', label: 'PASSED' },
  passed_with_warnings: { color: 'text-amber-400 bg-amber-500/10 border-amber-500/30', label: 'PASSED WITH WARNINGS' },
  failed: { color: 'text-red-400 bg-red-500/10 border-red-500/30', label: 'FAILED' },
  running: { color: 'text-blue-400 bg-blue-500/10 border-blue-500/30', label: 'RUNNING' },
  skipped: { color: 'text-slate-500 bg-slate-500/10 border-slate-500/30', label: 'SKIPPED' },
};

function formatDuration(s: number | null): string {
  if (!s) return '—';
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m ${s % 60}s`;
}

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
/* Collapsible Section                                                 */
/* ------------------------------------------------------------------ */
function CollapsibleSection({ title, defaultOpen = false, children }: {
  title: string; defaultOpen?: boolean; children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="border border-slate-700/50 rounded">
      <button onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-300 hover:bg-slate-800/50 transition-colors">
        {open ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
        {title}
      </button>
      {open && <div className="px-3 pb-3">{children}</div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Detail renderers per tool                                           */
/* ------------------------------------------------------------------ */
function SonarQubeDetails({ details }: { details: any }) {
  if (!details || typeof details !== 'object') return null;
  const { metrics, issuesByType, totalIssues, dashboardUrl, conditions } = details;
  return (
    <div className="space-y-4">
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
      <div className="flex gap-4 text-sm">
        <span className="text-emerald-400">{passed} passing</span>
        {failed > 0 && <span className="text-red-400">{failed} failing</span>}
        <span className="text-slate-500">{total} total</span>
      </div>
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
                  <div className={`text-lg font-mono ${pct >= 80 ? 'text-emerald-400' : pct >= 60 ? 'text-amber-400' : 'text-red-400'}`}>{pct}%</div>
                  <div className="text-xs text-slate-600">{c.covered}/{c.total}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
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
      {files && files.length > 0 && (
        <CollapsibleSection title={`Coverage by file (${files.length})`} defaultOpen={false}>
          <div className="space-y-1">
            {files.map((f: any, i: number) => (
              <div key={i} className="text-xs font-mono text-slate-400 flex gap-3">
                <span className="text-slate-300 truncate flex-1">{f.file}</span>
                <span>S:{f.statements}</span><span>B:{f.branches}</span><span>F:{f.functions}</span>
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
            <span key={k} className="mr-3"><span className="text-slate-600">{k}:</span> {String(v)}</span>
          ))}
        </div>
      )) : (
        <pre className="text-xs font-mono text-slate-400 whitespace-pre-wrap">{JSON.stringify(details, null, 2)}</pre>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Tool Card                                                           */
/* ------------------------------------------------------------------ */
function ToolCard({ phase }: { phase: PhaseResult }) {
  const [expanded, setExpanded] = useState(false);
  const cfg = STATUS_CONFIG[phase.status] || STATUS_CONFIG.skip;
  const icon = TOOL_ICONS[phase.tool] || <PackageSearch size={18} />;
  const label = TOOL_LABELS[phase.tool] || phase.tool;

  const renderDetails = () => {
    switch (phase.tool) {
      case 'sonarqube': return <SonarQubeDetails details={phase.details} />;
      case 'jest': return <JestDetails details={phase.details} />;
      case 'eslint': return <EslintDetails details={phase.details} />;
      default: return <GenericDetails details={phase.details} />;
    }
  };

  const hasDetails = phase.details && (
    (Array.isArray(phase.details) && phase.details.length > 0) ||
    (!Array.isArray(phase.details) && typeof phase.details === 'object' && Object.keys(phase.details).length > 0)
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
          {cfg.icon} {phase.summary}
        </span>
        {phase.durationMs && (
          <span className="text-xs text-slate-600 ml-2">{phase.durationMs}ms</span>
        )}
        <span className="ml-auto">
          {hasDetails && (expanded ? <ChevronDown size={16} className="text-slate-500" /> : <ChevronRight size={16} className="text-slate-500" />)}
        </span>
      </button>
      {expanded && hasDetails && (
        <div className="px-4 pb-4 border-t border-slate-700/30 pt-3">{renderDetails()}</div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Main Page                                                           */
/* ------------------------------------------------------------------ */
export default function ScanDetailPage() {
  const params = useParams();
  const projectId = params.id as string;
  const scanId = params.scanId as string;

  const [scan, setScan] = useState<Scan | null>(null);
  const [phases, setPhases] = useState<PhaseResult[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch(`${API_BASE}/scans/${scanId}`).then(r => r.json()),
      fetch(`${API_BASE}/scans/${scanId}/phases`).then(r => r.json()),
    ])
      .then(([scanData, phaseData]) => {
        setScan(scanData);
        setPhases(Array.isArray(phaseData) ? phaseData : []);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scanId]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <RefreshCw className="animate-spin text-slate-500" size={32} />
      </div>
    );
  }

  if (!scan) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 text-slate-500">
        <XCircle size={48} />
        <p className="text-lg">Scan not found</p>
        <Link href={`/projects/${projectId}`} className="text-blue-400 hover:underline">← Back to project</Link>
      </div>
    );
  }

  const badge = SCAN_STATUS_BADGE[scan.status] || SCAN_STATUS_BADGE.running;
  const counts = { pass: 0, fail: 0, warn: 0, skip: 0 };
  phases.forEach(p => {
    if (p.status in counts) counts[p.status as keyof typeof counts]++;
  });

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center gap-4">
          <Link href={`/projects/${projectId}`} className="text-slate-500 hover:text-slate-300 transition-colors">
            <ArrowLeft size={20} />
          </Link>
          <div>
            <h1 className="text-lg font-bold text-slate-200">
              Scan {scan.scanCode}
            </h1>
            <div className="text-xs text-slate-500 flex items-center gap-2">
              {scan.branchName && <span className="inline-flex items-center gap-1"><GitBranch size={12} /> {scan.branchName}</span>}
              <span className="inline-flex items-center gap-1"><Calendar size={12} /> {new Date(scan.startedAt).toLocaleString()}</span>
            </div>
          </div>
          <span className={`ml-auto px-3 py-1 rounded-full text-sm font-medium border ${badge.color}`}>
            {badge.label}
          </span>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Summary stats */}
        <div className="flex items-center gap-4 text-sm text-slate-500 mb-6">
          <span className="flex items-center gap-1"><Clock size={14} /> {formatDuration(scan.durationSeconds)}</span>
          {scan.errorsCount > 0 && <span className="text-red-400">{scan.errorsCount} error(s)</span>}
          {scan.warningsCount > 0 && <span className="text-amber-400">{scan.warningsCount} warning(s)</span>}
          <span>{phases.length} phase(s)</span>
        </div>

        {/* Summary cards */}
        <div className="grid grid-cols-4 gap-3 mb-6">
          {[
            { label: 'Passed', count: counts.pass, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
            { label: 'Failed', count: counts.fail, color: 'text-red-400', bg: 'bg-red-500/10' },
            { label: 'Warnings', count: counts.warn, color: 'text-amber-400', bg: 'bg-amber-500/10' },
            { label: 'Skipped', count: counts.skip, color: 'text-slate-500', bg: 'bg-slate-500/10' },
          ].map(({ label, count, color, bg }) => (
            <div key={label} className={`${bg} rounded-lg p-3 text-center border border-slate-700/30`}>
              <div className={`text-2xl font-bold ${color}`}>{count}</div>
              <div className="text-xs text-slate-500">{label}</div>
            </div>
          ))}
        </div>

        {/* Phase results */}
        <div className="space-y-2">
          {phases.map(phase => (
            <ToolCard key={phase.id} phase={phase} />
          ))}
        </div>
      </div>
    </div>
  );
}
