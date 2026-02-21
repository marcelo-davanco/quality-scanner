import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Project } from './entities/project.entity';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectRepository(Project)
    private readonly projectRepo: Repository<Project>,
  ) {}

  async create(dto: CreateProjectDto): Promise<Project> {
    const exists = await this.projectRepo.findOne({
      where: [{ name: dto.name }, { projectKey: dto.projectKey }],
    });
    if (exists) {
      throw new ConflictException('Project with this name or key already exists');
    }
    const project = this.projectRepo.create(dto);
    return this.projectRepo.save(project);
  }

  async findAll(): Promise<Project[]> {
    return this.projectRepo.find({ order: { createdAt: 'DESC' } });
  }

  async findOne(id: string): Promise<Project> {
    const project = await this.projectRepo.findOne({
      where: { id },
      relations: ['scans'],
    });
    if (!project) {
      throw new NotFoundException(`Project #${id} not found`);
    }
    return project;
  }

  async findByKey(projectKey: string): Promise<Project> {
    const project = await this.projectRepo.findOne({ where: { projectKey } });
    if (!project) {
      throw new NotFoundException(`Project with key "${projectKey}" not found`);
    }
    return project;
  }

  async findConfigsByKey(projectKey: string): Promise<{ profileName: string; configs: { tool: string; filename: string; content: string }[] }> {
    const project = await this.projectRepo.findOne({
      where: { projectKey },
      relations: ['qualityProfile', 'qualityProfile.configItems'],
    });
    if (!project) {
      throw new NotFoundException(`Project with key "${projectKey}" not found`);
    }
    if (!project.qualityProfile) {
      return { profileName: '', configs: [] };
    }
    return {
      profileName: project.qualityProfile.name,
      configs: (project.qualityProfile.configItems || []).map((item) => ({
        tool: item.tool,
        filename: item.filename,
        content: item.content,
      })),
    };
  }

  async update(id: string, dto: UpdateProjectDto): Promise<Project> {
    const project = await this.findOne(id);
    Object.assign(project, dto);
    return this.projectRepo.save(project);
  }

  async remove(id: string): Promise<void> {
    const project = await this.findOne(id);
    await this.projectRepo.remove(project);
  }
}
