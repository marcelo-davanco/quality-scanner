import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ScansService } from './scans.service';
import { CreateScanDto } from './dto/create-scan.dto';
import { UpdateScanDto } from './dto/update-scan.dto';
import { CreatePhaseResultDto } from './dto/create-phase-result.dto';

@ApiTags('Scans')
@Controller()
export class ScansController {
  constructor(private readonly scansService: ScansService) {}

  @Post('projects/:projectId/scans')
  @ApiOperation({ summary: 'Start a new scan for a project' })
  @ApiResponse({ status: 201, description: 'Scan created' })
  create(
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: CreateScanDto,
  ) {
    return this.scansService.create(projectId, dto);
  }

  @Get('projects/:projectId/scans')
  @ApiOperation({ summary: 'List scans for a project' })
  findByProject(@Param('projectId', ParseUUIDPipe) projectId: string) {
    return this.scansService.findByProject(projectId);
  }

  @Get('projects/:projectId/scans/latest')
  @ApiOperation({ summary: 'Get latest scan for a project' })
  getLatest(@Param('projectId', ParseUUIDPipe) projectId: string) {
    return this.scansService.getLatestByProject(projectId);
  }

  @Get('scans/:id')
  @ApiOperation({ summary: 'Get scan by ID (with phase results)' })
  @ApiResponse({ status: 404, description: 'Scan not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.scansService.findOne(id);
  }

  @Patch('scans/:id')
  @ApiOperation({ summary: 'Update scan status (used by scanner to finalize)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateScanDto,
  ) {
    return this.scansService.update(id, dto);
  }

  @Post('scans/:scanId/phases')
  @ApiOperation({ summary: 'Report a phase result for a scan' })
  @ApiResponse({ status: 201, description: 'Phase result recorded' })
  addPhaseResult(
    @Param('scanId', ParseUUIDPipe) scanId: string,
    @Body() dto: CreatePhaseResultDto,
  ) {
    return this.scansService.addPhaseResult(scanId, dto);
  }

  @Get('scans/:scanId/phases')
  @ApiOperation({ summary: 'List phase results for a scan' })
  getPhaseResults(@Param('scanId', ParseUUIDPipe) scanId: string) {
    return this.scansService.getPhaseResults(scanId);
  }
}
