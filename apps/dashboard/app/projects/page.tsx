'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  Shield, FolderOpen, Clock, RefreshCw
} from 'lucide-react';
import type { Project } from '../../lib/api';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export default function ProjectsPage() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`${API_BASE}/projects`)
      .then(r => r.json())
      .then(data => setProjects(Array.isArray(data) ? data : []))
      .catch(() => setProjects([]))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <RefreshCw className="animate-spin text-slate-500" size={32} />
      </div>
    );
  }

  const toggleCount = (p: Project) =>
    [p.enableGitleaks, p.enableTypescript, p.enableEslint, p.enablePrettier,
    p.enableAudit, p.enableKnip, p.enableJest, p.enableSonarqube,
    p.enableApiLint, p.enableInfraScan].filter(Boolean).length;

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <h1 className="text-xl font-bold text-slate-200 flex items-center gap-2">
            <Shield size={22} className="text-blue-400" />
            Quality Scanner
          </h1>
          <div className="flex items-center gap-4">
            <Link href="/quality-profiles" className="text-sm text-slate-400 hover:text-slate-200 transition-colors">
              Quality Profiles
            </Link>
          </div>
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-6 py-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-slate-200">Projects</h2>
          <span className="text-sm text-slate-500">{projects.length} project(s)</span>
        </div>

        {projects.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-4 text-slate-500 py-20">
            <FolderOpen size={48} />
            <p className="text-lg">No projects registered</p>
            <p className="text-sm">Run <code className="bg-slate-800 px-2 py-1 rounded">./scan.sh ./your-project</code> to auto-register a project</p>
          </div>
        ) : (
          <div className="grid gap-3">
            {projects.map(project => (
              <Link
                key={project.id}
                href={`/projects/${project.id}`}
                className="block border border-slate-800 rounded-lg p-4 hover:bg-slate-800/50 hover:border-slate-700 transition-all group"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <FolderOpen size={20} className="text-blue-400" />
                    <div>
                      <div className="font-medium text-slate-200 group-hover:text-white transition-colors">
                        {project.name}
                      </div>
                      <div className="text-xs text-slate-500 mt-0.5">
                        {project.projectKey}
                        {project.description && <span className="ml-2">· {project.description}</span>}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-slate-500">
                    <span>{toggleCount(project)}/10 phases</span>
                    <span className="flex items-center gap-1">
                      <Clock size={12} />
                      {new Date(project.createdAt).toLocaleDateString()}
                    </span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
