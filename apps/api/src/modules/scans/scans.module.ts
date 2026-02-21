import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Scan } from './entities/scan.entity';
import { PhaseResult } from './entities/phase-result.entity';
import { ScansService } from './scans.service';
import { ScansController } from './scans.controller';
import { ProjectsModule } from '../projects/projects.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Scan, PhaseResult]),
    ProjectsModule,
  ],
  controllers: [ScansController],
  providers: [ScansService],
  exports: [ScansService],
})
export class ScansModule {}
