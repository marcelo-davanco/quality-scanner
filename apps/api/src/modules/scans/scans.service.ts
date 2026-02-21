import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Scan, ScanStatus } from './entities/scan.entity';
import { PhaseResult } from './entities/phase-result.entity';
import { CreateScanDto } from './dto/create-scan.dto';
import { UpdateScanDto } from './dto/update-scan.dto';
import { CreatePhaseResultDto } from './dto/create-phase-result.dto';
import { ProjectsService } from '../projects/projects.service';

@Injectable()
export class ScansService {
  constructor(
    @InjectRepository(Scan)
    private readonly scanRepo: Repository<Scan>,
    @InjectRepository(PhaseResult)
    private readonly phaseResultRepo: Repository<PhaseResult>,
    private readonly projectsService: ProjectsService,
  ) {}

  async create(projectId: string, dto: CreateScanDto): Promise<Scan> {
    await this.projectsService.findOne(projectId);

    const scan = this.scanRepo.create({
      projectId,
      scanCode: new Date().toISOString().replace(/[-:T]/g, '').slice(0, 15),
      status: ScanStatus.RUNNING,
      startedAt: new Date(),
      branchName: dto.branchName || null,
      prKey: dto.prKey || null,
    });
    return this.scanRepo.save(scan);
  }

  async findByProject(projectId: string): Promise<Scan[]> {
    return this.scanRepo.find({
      where: { projectId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async findOne(id: string): Promise<Scan> {
    const scan = await this.scanRepo.findOne({
      where: { id },
      relations: ['phaseResults', 'project'],
    });
    if (!scan) {
      throw new NotFoundException(`Scan #${id} not found`);
    }
    return scan;
  }

  async update(id: string, dto: UpdateScanDto): Promise<Scan> {
    const scan = await this.findOne(id);
    Object.assign(scan, dto);

    if (dto.status && dto.status !== ScanStatus.RUNNING) {
      scan.finishedAt = new Date();
    }

    return this.scanRepo.save(scan);
  }

  async addPhaseResult(scanId: string, dto: CreatePhaseResultDto): Promise<PhaseResult> {
    await this.findOne(scanId);

    const phase = this.phaseResultRepo.create({
      scanId,
      tool: dto.tool,
      status: dto.status,
      summary: dto.summary,
      details: dto.details || [],
      durationMs: dto.durationMs || null,
    });
    return this.phaseResultRepo.save(phase);
  }

  async getPhaseResults(scanId: string): Promise<PhaseResult[]> {
    return this.phaseResultRepo.find({
      where: { scanId },
      order: { createdAt: 'ASC' },
    });
  }

  async getLatestByProject(projectId: string): Promise<Scan | null> {
    return this.scanRepo.findOne({
      where: { projectId },
      order: { createdAt: 'DESC' },
      relations: ['phaseResults'],
    });
  }
}
