import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Scan } from './scan.entity';

export enum PhaseStatus {
  PASS = 'pass',
  FAIL = 'fail',
  WARN = 'warn',
  SKIP = 'skip',
}

@Entity('phase_results')
export class PhaseResult {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'scan_id' })
  scanId: string;

  @ManyToOne(() => Scan, (scan) => scan.phaseResults, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'scan_id' })
  scan: Scan;

  @Column({ type: 'varchar', length: 50 })
  tool: string;

  @Column({ type: 'enum', enum: PhaseStatus })
  status: PhaseStatus;

  @Column({ type: 'text' })
  summary: string;

  @Column({ type: 'jsonb', default: '[]' })
  details: Record<string, unknown> | unknown[];

  @Column({ type: 'int', nullable: true, name: 'duration_ms' })
  durationMs: number | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
