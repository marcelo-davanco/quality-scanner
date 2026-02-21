import {
  IsString,
  IsOptional,
  IsBoolean,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateProjectDto {
  @ApiProperty({ example: 'my-nestjs-api', description: 'Unique project name' })
  @IsString()
  @MinLength(2)
  @MaxLength(255)
  name: string;

  @ApiProperty({ example: 'my-nestjs-api', description: 'SonarQube project key' })
  @IsString()
  @MinLength(2)
  @MaxLength(255)
  projectKey: string;

  @ApiPropertyOptional({ example: 'https://github.com/org/repo' })
  @IsOptional()
  @IsUrl()
  @MaxLength(500)
  repositoryUrl?: string;

  @ApiPropertyOptional({ example: 'Main backend API' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  // ── SonarQube Settings ──────────────────────────────────
  @ApiPropertyOptional({ example: 'http://sonarqube:9000' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  sonarHostUrl?: string;

  @ApiPropertyOptional({ example: 'squ_abc123' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  sonarToken?: string;

  // ── Phase Toggles ───────────────────────────────────────
  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableGitleaks?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableTypescript?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableEslint?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enablePrettier?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableAudit?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableKnip?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableJest?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  enableSonarqube?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  enableApiLint?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  enableInfraScan?: boolean;

  // ── Quality Profile ────────────────────────────────────
  @ApiPropertyOptional({ description: 'UUID of the quality profile to assign' })
  @IsOptional()
  @IsString()
  qualityProfileId?: string | null;

  // ── Extra Config ────────────────────────────────────────
  @ApiPropertyOptional({ default: 'warn' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  apiLintSeverity?: string;

  @ApiPropertyOptional({ default: 'HIGH' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  infraScanSeverity?: string;
}
