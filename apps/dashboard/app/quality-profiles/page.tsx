'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  Settings, Clock, RefreshCw,
  CheckCircle2, XCircle, Plus, FileCode
} from 'lucide-react';
import type { QualityProfile } from '../../lib/api';
import { postApi } from '../../lib/api';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export default function QualityProfilesPage() {
  const [profiles, setProfiles] = useState<QualityProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');

  const fetchProfiles = () => {
    fetch(`${API_BASE}/quality-profiles`)
      .then(r => r.json())
      .then(data => setProfiles(Array.isArray(data) ? data : []))
      .catch(() => setProfiles([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => { fetchProfiles(); }, []);

  const handleCreate = async () => {
    if (!newName.trim()) return;
    try {
      await postApi('/quality-profiles', { name: newName.trim(), description: newDesc.trim() || undefined });
      setNewName('');
      setNewDesc('');
      setShowCreate(false);
      setLoading(true);
      fetchProfiles();
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

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <h1 className="text-xl font-bold text-slate-200 flex items-center gap-2">
            <Settings size={22} className="text-purple-400" />
            Quality Profiles
          </h1>
          <div className="flex items-center gap-4">
            <Link href="/projects" className="text-sm text-slate-400 hover:text-slate-200 transition-colors">
              Projects
            </Link>
          </div>
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-6 py-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-slate-200">{profiles.length} profile(s)</h2>
          <button
            onClick={() => setShowCreate(!showCreate)}
            className="flex items-center gap-2 px-3 py-2 text-sm bg-purple-500/10 text-purple-400 border border-purple-500/30 rounded-lg hover:bg-purple-500/20 transition-colors"
          >
            <Plus size={16} /> New Profile
          </button>
        </div>

        {/* Create form */}
        {showCreate && (
          <div className="border border-purple-500/30 rounded-lg p-4 mb-6 bg-purple-500/5">
            <div className="grid gap-3">
              <input
                type="text"
                placeholder="Profile name (e.g. Strict Frontend)"
                value={newName}
                onChange={e => setNewName(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-purple-500"
              />
              <input
                type="text"
                placeholder="Description (optional)"
                value={newDesc}
                onChange={e => setNewDesc(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-purple-500"
              />
              <div className="flex gap-2">
                <button
                  onClick={handleCreate}
                  className="px-4 py-2 text-sm bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors"
                >
                  Create
                </button>
                <button
                  onClick={() => setShowCreate(false)}
                  className="px-4 py-2 text-sm text-slate-400 hover:text-slate-200 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}

        {profiles.length === 0 && !showCreate ? (
          <div className="flex flex-col items-center justify-center gap-4 text-slate-500 py-20">
            <Settings size={48} />
            <p className="text-lg">No quality profiles yet</p>
            <p className="text-sm">Create a profile to define reusable config sets for your projects</p>
          </div>
        ) : (
          <div className="grid gap-3">
            {profiles.map(profile => (
              <Link
                key={profile.id}
                href={`/quality-profiles/${profile.id}`}
                className="block border border-slate-800 rounded-lg p-4 hover:bg-slate-800/50 hover:border-slate-700 transition-all group"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Settings size={20} className="text-purple-400" />
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-slate-200 group-hover:text-white transition-colors">
                          {profile.name}
                        </span>
                        {profile.isActive ? (
                          <span className="flex items-center gap-1 text-xs text-emerald-400">
                            <CheckCircle2 size={12} /> Active
                          </span>
                        ) : (
                          <span className="flex items-center gap-1 text-xs text-slate-500">
                            <XCircle size={12} /> Inactive
                          </span>
                        )}
                      </div>
                      {profile.description && (
                        <div className="text-xs text-slate-500 mt-0.5">{profile.description}</div>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-slate-500">
                    <span className="flex items-center gap-1">
                      <FileCode size={12} /> {profile.configItems?.length || 0} config(s)
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock size={12} />
                      {new Date(profile.createdAt).toLocaleDateString()}
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
