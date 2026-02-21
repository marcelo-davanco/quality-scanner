'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft, Settings, RefreshCw, FileCode,
  CheckCircle2, XCircle, Plus, Trash2, ChevronDown,
  ChevronRight, FolderOpen, Code
} from 'lucide-react';
import type { QualityProfile, Project } from '../../../lib/api';
import { postApi, patchApi, deleteApi } from '../../../lib/api';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

const TOOL_OPTIONS = [
  'eslint', 'prettier', 'typescript', 'gitleaks', 'knip',
  'sonarqube', 'stryker', 'commitlint', 'editorconfig',
  'husky', 'lintstaged', 'swagger', 'other',
];

export default function QualityProfileDetailPage() {
  const params = useParams();
  const profileId = params.id as string;

  const [profile, setProfile] = useState<QualityProfile | null>(null);
  const [allProjects, setAllProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddConfig, setShowAddConfig] = useState(false);
  const [expandedItem, setExpandedItem] = useState<string | null>(null);

  // New config form
  const [newTool, setNewTool] = useState('eslint');
  const [newFilename, setNewFilename] = useState('');
  const [newContent, setNewContent] = useState('');
  const [newItemDesc, setNewItemDesc] = useState('');

  const fetchData = () => {
    Promise.all([
      fetch(`${API_BASE}/quality-profiles/${profileId}`).then(r => r.json()),
      fetch(`${API_BASE}/projects`).then(r => r.json()),
    ])
      .then(([prof, projs]) => {
        setProfile(prof);
        setAllProjects(Array.isArray(projs) ? projs : []);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { fetchData(); }, [profileId]);

  const handleAddConfig = async () => {
    if (!newFilename.trim() || !newContent.trim()) return;
    try {
      await postApi(`/quality-profiles/${profileId}/configs`, {
        tool: newTool,
        filename: newFilename.trim(),
        content: newContent,
        description: newItemDesc.trim() || undefined,
      });
      setNewTool('eslint');
      setNewFilename('');
      setNewContent('');
      setNewItemDesc('');
      setShowAddConfig(false);
      setLoading(true);
      fetchData();
    } catch (e) {
      alert(`Error: ${e}`);
    }
  };

  const handleDeleteConfig = async (itemId: string) => {
    if (!confirm('Delete this config item?')) return;
    try {
      await deleteApi(`/quality-profiles/configs/${itemId}`);
      setLoading(true);
      fetchData();
    } catch (e) {
      alert(`Error: ${e}`);
    }
  };

  const handleAssignProfile = async (projectId: string) => {
    try {
      await patchApi(`/projects/${projectId}`, { qualityProfileId: profileId });
      setLoading(true);
      fetchData();
    } catch (e) {
      alert(`Error: ${e}`);
    }
  };

  const handleUnassignProfile = async (projectId: string) => {
    try {
      await patchApi(`/projects/${projectId}`, { qualityProfileId: null });
      setLoading(true);
      fetchData();
    } catch (e) {
      alert(`Error: ${e}`);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <RefreshCw className="animate-spin text-slate-500" size={32} />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 text-slate-500">
        <XCircle size={48} />
        <p className="text-lg">Profile not found</p>
        <Link href="/quality-profiles" className="text-purple-400 hover:underline">← Back to profiles</Link>
      </div>
    );
  }

  const linkedProjectIds = new Set((profile.projects || []).map(p => p.id));
  const unlinkedProjects = allProjects.filter(p => !linkedProjectIds.has(p.id));

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-6 py-4 flex items-center gap-4">
          <Link href="/quality-profiles" className="text-slate-500 hover:text-slate-300 transition-colors">
            <ArrowLeft size={20} />
          </Link>
          <Settings size={20} className="text-purple-400" />
          <div>
            <h1 className="text-xl font-bold text-slate-200">{profile.name}</h1>
            {profile.description && <p className="text-xs text-slate-500">{profile.description}</p>}
          </div>
          <span className={`ml-auto flex items-center gap-1 text-xs px-2 py-1 rounded-full border ${profile.isActive ? 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30' : 'text-slate-500 bg-slate-500/10 border-slate-500/30'}`}>
            {profile.isActive ? <><CheckCircle2 size={12} /> Active</> : <><XCircle size={12} /> Inactive</>}
          </span>
        </div>
      </header>

      <div className="max-w-5xl mx-auto px-6 py-8 space-y-8">
        {/* ── Config Items ──────────────────────────────── */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-slate-200 flex items-center gap-2">
              <FileCode size={18} className="text-purple-400" />
              Config Items ({profile.configItems?.length || 0})
            </h2>
            <button
              onClick={() => setShowAddConfig(!showAddConfig)}
              className="flex items-center gap-2 px-3 py-1.5 text-sm bg-purple-500/10 text-purple-400 border border-purple-500/30 rounded-lg hover:bg-purple-500/20 transition-colors"
            >
              <Plus size={14} /> Add Config
            </button>
          </div>

          {/* Add config form */}
          {showAddConfig && (
            <div className="border border-purple-500/30 rounded-lg p-4 mb-4 bg-purple-500/5 space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-slate-400 mb-1 block">Tool</label>
                  <select
                    value={newTool}
                    onChange={e => setNewTool(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-purple-500"
                  >
                    {TOOL_OPTIONS.map(t => <option key={t} value={t}>{t}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-slate-400 mb-1 block">Filename</label>
                  <input
                    type="text"
                    placeholder=".eslintrc.js"
                    value={newFilename}
                    onChange={e => setNewFilename(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs text-slate-400 mb-1 block">Description (optional)</label>
                <input
                  type="text"
                  placeholder="Strict ESLint config with no-any rule"
                  value={newItemDesc}
                  onChange={e => setNewItemDesc(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-purple-500"
                />
              </div>
              <div>
                <label className="text-xs text-slate-400 mb-1 block">Content</label>
                <textarea
                  placeholder="Paste the full config file content here..."
                  value={newContent}
                  onChange={e => setNewContent(e.target.value)}
                  rows={10}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-purple-500 font-mono"
                />
              </div>
              <div className="flex gap-2">
                <button onClick={handleAddConfig} className="px-4 py-2 text-sm bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors">
                  Add
                </button>
                <button onClick={() => setShowAddConfig(false)} className="px-4 py-2 text-sm text-slate-400 hover:text-slate-200 transition-colors">
                  Cancel
                </button>
              </div>
            </div>
          )}

          {/* Config items list */}
          {(!profile.configItems || profile.configItems.length === 0) ? (
            <div className="text-center py-8 text-slate-500 border border-slate-800 rounded-lg">
              <FileCode size={32} className="mx-auto mb-2 opacity-50" />
              <p className="text-sm">No config items yet. Add configs for eslint, prettier, etc.</p>
            </div>
          ) : (
            <div className="space-y-2">
              {profile.configItems.map(item => {
                const isExpanded = expandedItem === item.id;
                return (
                  <div key={item.id} className="border border-slate-800 rounded-lg overflow-hidden">
                    <div className="flex items-center gap-3 px-4 py-3 hover:bg-slate-800/50 transition-colors">
                      <button
                        onClick={() => setExpandedItem(isExpanded ? null : item.id)}
                        className="flex items-center gap-3 flex-1 text-left"
                      >
                        {isExpanded ? <ChevronDown size={14} className="text-slate-500" /> : <ChevronRight size={14} className="text-slate-500" />}
                        <Code size={16} className="text-purple-400" />
                        <div>
                          <span className="text-sm font-medium text-slate-200">{item.filename}</span>
                          <span className="ml-2 text-xs px-1.5 py-0.5 rounded bg-slate-700 text-slate-400">{item.tool}</span>
                        </div>
                        {item.description && (
                          <span className="text-xs text-slate-500 ml-2 truncate">{item.description}</span>
                        )}
                      </button>
                      <button
                        onClick={() => handleDeleteConfig(item.id)}
                        className="text-slate-600 hover:text-red-400 transition-colors p-1"
                        title="Delete config item"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                    {isExpanded && (
                      <div className="border-t border-slate-800 bg-slate-900/50 p-4">
                        <pre className="text-xs font-mono text-slate-300 whitespace-pre-wrap max-h-96 overflow-auto">
                          {item.content}
                        </pre>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* ── Linked Projects ──────────────────────────── */}
        <section>
          <h2 className="text-lg font-semibold text-slate-200 flex items-center gap-2 mb-4">
            <FolderOpen size={18} className="text-blue-400" />
            Linked Projects ({profile.projects?.length || 0})
          </h2>

          {/* Linked */}
          {profile.projects && profile.projects.length > 0 ? (
            <div className="space-y-2 mb-4">
              {profile.projects.map(project => (
                <div key={project.id} className="flex items-center justify-between border border-slate-800 rounded-lg px-4 py-3">
                  <Link href={`/projects/${project.id}`} className="flex items-center gap-2 text-sm text-slate-200 hover:text-white transition-colors">
                    <FolderOpen size={16} className="text-blue-400" />
                    {project.name}
                    <span className="text-xs text-slate-500">{project.projectKey}</span>
                  </Link>
                  <button
                    onClick={() => handleUnassignProfile(project.id)}
                    className="text-xs text-slate-500 hover:text-red-400 transition-colors flex items-center gap-1"
                  >
                    <XCircle size={12} /> Unlink
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-6 text-slate-500 border border-slate-800 rounded-lg mb-4">
              <p className="text-sm">No projects linked to this profile</p>
            </div>
          )}

          {/* Unlinked projects to assign */}
          {unlinkedProjects.length > 0 && (
            <div>
              <h3 className="text-sm font-medium text-slate-400 mb-2">Available projects</h3>
              <div className="space-y-1">
                {unlinkedProjects.map(project => (
                  <div key={project.id} className="flex items-center justify-between border border-slate-800/50 rounded-lg px-4 py-2">
                    <span className="text-sm text-slate-400">
                      {project.name} <span className="text-xs text-slate-600">{project.projectKey}</span>
                    </span>
                    <button
                      onClick={() => handleAssignProfile(project.id)}
                      className="text-xs text-purple-400 hover:text-purple-300 transition-colors flex items-center gap-1"
                    >
                      <Plus size={12} /> Link
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
