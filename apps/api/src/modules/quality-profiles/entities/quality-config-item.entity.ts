import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { QualityProfile } from './quality-profile.entity';

@Entity('quality_config_items')
export class QualityConfigItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'profile_id' })
  profileId: string;

  @ManyToOne(() => QualityProfile, (profile) => profile.configItems, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'profile_id' })
  profile: QualityProfile;

  @Column({ type: 'varchar', length: 100 })
  tool: string;

  @Column({ type: 'varchar', length: 255 })
  filename: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ type: 'varchar', length: 500, nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamp with time zone' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamp with time zone' })
  updatedAt: Date;
}
