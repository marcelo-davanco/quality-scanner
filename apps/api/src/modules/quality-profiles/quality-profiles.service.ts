import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { QualityProfile } from './entities/quality-profile.entity';
import { QualityConfigItem } from './entities/quality-config-item.entity';
import { CreateQualityProfileDto } from './dto/create-quality-profile.dto';
import { UpdateQualityProfileDto } from './dto/update-quality-profile.dto';
import { CreateConfigItemDto } from './dto/create-config-item.dto';
import { UpdateConfigItemDto } from './dto/update-config-item.dto';

@Injectable()
export class QualityProfilesService {
  constructor(
    @InjectRepository(QualityProfile)
    private readonly profileRepo: Repository<QualityProfile>,
    @InjectRepository(QualityConfigItem)
    private readonly configItemRepo: Repository<QualityConfigItem>,
  ) {}

  // ── Profiles ────────────────────────────────────────────

  async create(dto: CreateQualityProfileDto): Promise<QualityProfile> {
    const exists = await this.profileRepo.findOneBy({ name: dto.name });
    if (exists) throw new ConflictException(`Profile "${dto.name}" already exists`);
    return this.profileRepo.save(this.profileRepo.create(dto));
  }

  async findAll(): Promise<QualityProfile[]> {
    return this.profileRepo.find({
      relations: ['configItems'],
      order: { name: 'ASC' },
    });
  }

  async findOne(id: string): Promise<QualityProfile> {
    const profile = await this.profileRepo.findOne({
      where: { id },
      relations: ['configItems', 'projects'],
    });
    if (!profile) throw new NotFoundException(`Profile ${id} not found`);
    return profile;
  }

  async update(id: string, dto: UpdateQualityProfileDto): Promise<QualityProfile> {
    const profile = await this.findOne(id);
    Object.assign(profile, dto);
    return this.profileRepo.save(profile);
  }

  async remove(id: string): Promise<void> {
    const profile = await this.findOne(id);
    await this.profileRepo.remove(profile);
  }

  // ── Config Items ────────────────────────────────────────

  async addConfigItem(profileId: string, dto: CreateConfigItemDto): Promise<QualityConfigItem> {
    await this.findOne(profileId);
    const item = this.configItemRepo.create({ ...dto, profileId });
    return this.configItemRepo.save(item);
  }

  async getConfigItems(profileId: string): Promise<QualityConfigItem[]> {
    await this.findOne(profileId);
    return this.configItemRepo.find({
      where: { profileId },
      order: { tool: 'ASC', filename: 'ASC' },
    });
  }

  async getConfigItem(itemId: string): Promise<QualityConfigItem> {
    const item = await this.configItemRepo.findOneBy({ id: itemId });
    if (!item) throw new NotFoundException(`Config item ${itemId} not found`);
    return item;
  }

  async updateConfigItem(itemId: string, dto: UpdateConfigItemDto): Promise<QualityConfigItem> {
    const item = await this.getConfigItem(itemId);
    Object.assign(item, dto);
    return this.configItemRepo.save(item);
  }

  async removeConfigItem(itemId: string): Promise<void> {
    const item = await this.getConfigItem(itemId);
    await this.configItemRepo.remove(item);
  }
}
