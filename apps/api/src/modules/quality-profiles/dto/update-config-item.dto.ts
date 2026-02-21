import { PartialType } from '@nestjs/swagger';
import { CreateConfigItemDto } from './create-config-item.dto';

export class UpdateConfigItemDto extends PartialType(CreateConfigItemDto) {}
