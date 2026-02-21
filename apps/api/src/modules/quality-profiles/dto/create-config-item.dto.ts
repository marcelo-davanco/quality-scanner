import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, MaxLength, IsOptional } from 'class-validator';

export class CreateConfigItemDto {
  @ApiProperty({ example: 'eslint', description: 'Tool name (eslint, prettier, typescript, gitleaks, knip, sonarqube, etc.)' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  tool: string;

  @ApiProperty({ example: '.eslintrc.js', description: 'Config filename as it will be written to the project' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  filename: string;

  @ApiProperty({ example: 'module.exports = { ... }', description: 'Full file content' })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiPropertyOptional({ example: 'Strict ESLint config with no-any rule' })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;
}
