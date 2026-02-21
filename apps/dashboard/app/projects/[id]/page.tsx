'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft, Clock, CheckCircle2, XCircle,
  AlertTriangle, RefreshCw, SkipForward, GitBranch, FolderOpen
} from 'lucide-react';
import type { Project, Scan } from '../../../lib/api';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

const STATUS_BADGE: Record<string, { color: string; icon: React.ReactNode; label: string }> = {
  passed: { color: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30', icon: <CheckCircle2 size={14} />, label: 'Passed' },
  passed_with_warnings: { color: 'text-amber-400 bg-amber-500/10 border-amber-500/30', icon: <AlertTriangle size={14} />, label: 'Warnings' },
  failed: { color: 'text-red-400 bg-red-500/10 border-red-500/30', icon: <XCircle size={14} />, label: 'Failed' },
  running: { color: 'text-blue-400 bg-blue-500/10 border-blue-500/30', icon: <RefreshCw size={14} className="animate-spin" />, label: 'Running' },
  skipped: { color: 'text-slate-500 bg-slate-500/10 border-slate-500/30', icon: <SkipForward size={14} />, label: 'Skipped' },
};

function formatDuration(s: number | null): string {
  if (!s) return '—';
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m ${s % 60}s`;
}

export default function ProjectDetailPage() {
  const params = useParams();
  const projectId = params.id as string;

  const [project, setProject] = useState<Project | null>(null);
  const [scans, setScans] = useState<Scan[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch(`${API_BASE}/projects/${projectId}`).then(r => r.json()),
      fetch(`${API_BASE}/projects/${projectId}/scans`).then(r => r.json()),
    ])
      .then(([proj, scanList]) => {
        setProject(proj);
        setScans(Array.isArray(scanList) ? scanList : []);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [projectId]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <RefreshCw className="animate-spin text-slate-500" size={32} />
      </div>
    );
  }

  if (!project) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 text-slate-500">
        <XCircle size={48} />
        <p className="text-lg">Project not found</p>
        <Link href="/projects" className="text-blue-400 hover:underline">← Back to projects</Link>
      </div>
    );
  }

  const enabledPhases = [
    project.enableGitleaks && 'Gitleaks',
    project.enableTypescript && 'TypeScript',
    project.enableEslint && 'ESLint',
    project.enablePrettier && 'Prettier',
    project.enableAudit && 'Audit',
    project.enableKnip && 'Knip',
    project.enableJest && 'Jest',
    project.enableSonarqube && 'SonarQube',
    project.enableApiLint && 'API Lint',
    project.enableInfraScan && 'Infra Scan',
  ].filter(Boolean);

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center gap-4">
          <Link href="/projects" className="text-slate-500 hover:text-slate-300 transition-colors">
            <ArrowLeft size={20} />
          </Link>
          <div className="flex items-center gap-2">
            <FolderOpen size={20} className="text-blue-400" />
            <h1 className="text-xl font-bold text-slate-200">{project.name}</h1>
          </div>
          <span className="text-sm text-slate-500">{project.projectKey}</span>
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-6 py-8">
        {/* Project info */}
        <div className="border border-slate-800 rounded-lg p-4 mb-8">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
            <div>
              <div className="text-xs text-slate-500 mb-1">Phases enabled</div>
              <div className="text-slate-300">{enabledPhases.length}/10</div>
            </div>
            <div>
              <div className="text-xs text-slate-500 mb-1">Total scans</div>
              <div className="text-slate-300">{scans.length}</div>
            </div>
            <div>
              <div className="text-xs text-slate-500 mb-1">SonarQube</div>
              <div className="text-slate-300 truncate">{project.sonarHostUrl}</div>
            </div>
            <div>
              <div className="text-xs text-slate-500 mb-1">Created</div>
              <div className="text-slate-300">{new Date(project.createdAt).toLocaleDateString()}</div>
            </div>
          </div>
          {project.description && (
            <div className="mt-3 text-sm text-slate-400">{project.description}</div>
          )}
          <div className="mt-3 flex flex-wrap gap-1.5">
            {enabledPhases.map(phase => (
              <span key={phase as string} className="px-2 py-0.5 text-xs rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">
                {phase}
              </span>
            ))}
          </div>
        </div>

        {/* Scans list */}
        <h2 className="text-lg font-semibold text-slate-200 mb-4">Scan History</h2>

        {scans.length === 0 ? (
          <div className="text-center py-12 text-slate-500">
            <p>No scans yet</p>
            <p className="text-sm mt-1">Run <code className="bg-slate-800 px-2 py-1 rounded">./scan.sh ./your-project</code></p>
          </div>
        ) : (
          <div className="space-y-2">
            {scans.map(scan => {
              const badge = STATUS_BADGE[scan.status] || STATUS_BADGE.running;
              return (
                <Link
                  key={scan.id}
                  href={`/projects/${projectId}/scans/${scan.id}`}
                  className="flex items-center gap-4 border border-slate-800 rounded-lg p-4 hover:bg-slate-800/50 hover:border-slate-700 transition-all group"
                >
                  <span className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border ${badge.color}`}>
                    {badge.icon} {badge.label}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm text-slate-300 font-medium">
                      {scan.scanCode}
                      {scan.branchName && (
                        <span className="ml-2 text-xs text-slate-500 inline-flex items-center gap-1">
                          <GitBranch size={12} /> {scan.branchName}
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-slate-500 mt-0.5">
                      {new Date(scan.startedAt).toLocaleString()}
                    </div>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-slate-500">
                    {scan.errorsCount > 0 && <span className="text-red-400">{scan.errorsCount} error(s)</span>}
                    {scan.warningsCount > 0 && <span className="text-amber-400">{scan.warningsCount} warning(s)</span>}
                    <span className="flex items-center gap-1">
                      <Clock size={12} /> {formatDuration(scan.durationSeconds)}
                    </span>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
