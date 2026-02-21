import { PartialType } from '@nestjs/swagger';
import { CreateQualityProfileDto } from './create-quality-profile.dto';

export class UpdateQualityProfileDto extends PartialType(CreateQualityProfileDto) {}
