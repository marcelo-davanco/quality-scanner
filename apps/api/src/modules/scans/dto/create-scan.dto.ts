import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class CreateScanDto {
  @ApiPropertyOptional({ example: 'feature/my-feature' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  branchName?: string;

  @ApiPropertyOptional({ example: '123' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  prKey?: string;
}
