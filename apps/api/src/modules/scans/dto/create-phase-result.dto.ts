import { IsEnum, IsInt, IsObject, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PhaseStatus } from '../entities/phase-result.entity';

export class CreatePhaseResultDto {
  @ApiProperty({ example: 'eslint' })
  @IsString()
  @MaxLength(50)
  tool: string;

  @ApiProperty({ enum: PhaseStatus })
  @IsEnum(PhaseStatus)
  status: PhaseStatus;

  @ApiProperty({ example: '3 erro(s), 2 warning(s)' })
  @IsString()
  summary: string;

  @ApiPropertyOptional({ example: [], description: 'Tool-specific details (JSON)' })
  @IsOptional()
  details?: Record<string, unknown> | unknown[];

  @ApiPropertyOptional({ example: 1500 })
  @IsOptional()
  @IsInt()
  @Min(0)
  durationMs?: number;
}
