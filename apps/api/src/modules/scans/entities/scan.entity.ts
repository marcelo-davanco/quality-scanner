import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Project } from '../../projects/entities/project.entity';
import { PhaseResult } from './phase-result.entity';

export enum ScanStatus {
  RUNNING = 'running',
  PASSED = 'passed',
  PASSED_WITH_WARNINGS = 'passed_with_warnings',
  FAILED = 'failed',
}

@Entity('scans')
export class Scan {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'project_id' })
  projectId: string;

  @ManyToOne(() => Project, (project) => project.scans, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'project_id' })
  project: Project;

  @Column({ type: 'varchar', length: 50, name: 'scan_code' })
  scanCode: string;

  @Column({ type: 'enum', enum: ScanStatus, default: ScanStatus.RUNNING })
  status: ScanStatus;

  @Column({ type: 'int', default: 0, name: 'errors_count' })
  errorsCount: number;

  @Column({ type: 'int', default: 0, name: 'warnings_count' })
  warningsCount: number;

  @Column({ type: 'int', nullable: true, name: 'duration_seconds' })
  durationSeconds: number | null;

  @Column({ type: 'varchar', length: 255, nullable: true, name: 'branch_name' })
  branchName: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true, name: 'pr_key' })
  prKey: string | null;

  @Column({ type: 'timestamp', name: 'started_at' })
  startedAt: Date;

  @Column({ type: 'timestamp', nullable: true, name: 'finished_at' })
  finishedAt: Date | null;

  // ── Relations ───────────────────────────────────────────
  @OneToMany(() => PhaseResult, (phase) => phase.scan, { cascade: true })
  phaseResults: PhaseResult[];

  // ── Timestamps ──────────────────────────────────────────
  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
