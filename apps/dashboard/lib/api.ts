const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

async function fetchApi<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export interface Project {
  id: string;
  name: string;
  projectKey: string;
  repositoryUrl: string | null;
  description: string | null;
  sonarHostUrl: string;
  enableGitleaks: boolean;
  enableTypescript: boolean;
  enableEslint: boolean;
  enablePrettier: boolean;
  enableAudit: boolean;
  enableKnip: boolean;
  enableJest: boolean;
  enableSonarqube: boolean;
  enableApiLint: boolean;
  enableInfraScan: boolean;
  qualityProfileId: string | null;
  qualityProfile?: QualityProfile | null;
  createdAt: string;
  updatedAt: string;
}

export interface PhaseResult {
  id: string;
  scanId: string;
  tool: string;
  status: 'pass' | 'fail' | 'warn' | 'skip';
  summary: string;
  details: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  durationMs: number | null;
  createdAt: string;
}

export interface Scan {
  id: string;
  projectId: string;
  scanCode: string;
  status: 'running' | 'passed' | 'passed_with_warnings' | 'failed' | 'skipped';
  errorsCount: number;
  warningsCount: number;
  durationSeconds: number | null;
  branchName: string | null;
  prKey: string | null;
  startedAt: string;
  finishedAt: string | null;
  createdAt: string;
  project?: Project;
  phaseResults?: PhaseResult[];
}

export async function getProjects(): Promise<Project[]> {
  return fetchApi<Project[]>('/projects');
}

export async function getProject(id: string): Promise<Project> {
  return fetchApi<Project>(`/projects/${id}`);
}

export async function getProjectScans(projectId: string): Promise<Scan[]> {
  return fetchApi<Scan[]>(`/projects/${projectId}/scans`);
}

export async function getScan(id: string): Promise<Scan> {
  return fetchApi<Scan>(`/scans/${id}`);
}

export async function getScanPhases(scanId: string): Promise<PhaseResult[]> {
  return fetchApi<PhaseResult[]>(`/scans/${scanId}/phases`);
}

// ── Quality Profiles ──────────────────────────────────────

export interface QualityConfigItem {
  id: string;
  profileId: string;
  tool: string;
  filename: string;
  content: string;
  description: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface QualityProfile {
  id: string;
  name: string;
  description: string | null;
  isActive: boolean;
  configItems?: QualityConfigItem[];
  projects?: Project[];
  createdAt: string;
  updatedAt: string;
}

export async function getQualityProfiles(): Promise<QualityProfile[]> {
  return fetchApi<QualityProfile[]>('/quality-profiles');
}

export async function getQualityProfile(id: string): Promise<QualityProfile> {
  return fetchApi<QualityProfile>(`/quality-profiles/${id}`);
}

export async function getProfileConfigs(profileId: string): Promise<QualityConfigItem[]> {
  return fetchApi<QualityConfigItem[]>(`/quality-profiles/${profileId}/configs`);
}

export { API_BASE };

export async function patchApi<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function postApi<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function deleteApi(path: string): Promise<void> {
  const res = await fetch(`${API_BASE}${path}`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}
