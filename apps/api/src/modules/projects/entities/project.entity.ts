import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Scan } from '../../scans/entities/scan.entity';
import { QualityProfile } from '../../quality-profiles/entities/quality-profile.entity';

@Entity('projects')
export class Project {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  name: string;

  @Column({ type: 'varchar', length: 255, unique: true, name: 'project_key' })
  projectKey: string;

  @Column({ type: 'varchar', length: 500, nullable: true, name: 'repository_url' })
  repositoryUrl: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true, name: 'description' })
  description: string | null;

  // ── SonarQube Settings ──────────────────────────────────
  @Column({ type: 'varchar', length: 500, default: 'http://sonarqube:9000', name: 'sonar_host_url' })
  sonarHostUrl: string;

  @Column({ type: 'varchar', length: 500, nullable: true, name: 'sonar_token' })
  sonarToken: string | null;

  // ── Phase Toggles ───────────────────────────────────────
  @Column({ type: 'boolean', default: true, name: 'enable_gitleaks' })
  enableGitleaks: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_typescript' })
  enableTypescript: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_eslint' })
  enableEslint: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_prettier' })
  enablePrettier: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_audit' })
  enableAudit: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_knip' })
  enableKnip: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_jest' })
  enableJest: boolean;

  @Column({ type: 'boolean', default: true, name: 'enable_sonarqube' })
  enableSonarqube: boolean;

  @Column({ type: 'boolean', default: false, name: 'enable_api_lint' })
  enableApiLint: boolean;

  @Column({ type: 'boolean', default: false, name: 'enable_infra_scan' })
  enableInfraScan: boolean;

  // ── Extra Config ────────────────────────────────────────
  @Column({ type: 'varchar', length: 50, default: 'warn', name: 'api_lint_severity' })
  apiLintSeverity: string;

  @Column({ type: 'varchar', length: 50, default: 'HIGH', name: 'infra_scan_severity' })
  infraScanSeverity: string;

  // ── Relations ───────────────────────────────────────────
  @Column({ type: 'uuid', nullable: true, name: 'quality_profile_id' })
  qualityProfileId: string | null;

  @ManyToOne(() => QualityProfile, (profile) => profile.projects, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'quality_profile_id' })
  qualityProfile: QualityProfile | null;

  @OneToMany(() => Scan, (scan) => scan.project)
  scans: Scan[];

  // ── Timestamps ──────────────────────────────────────────
  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
