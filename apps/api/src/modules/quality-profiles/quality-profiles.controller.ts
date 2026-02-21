import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { QualityProfilesService } from './quality-profiles.service';
import { CreateQualityProfileDto } from './dto/create-quality-profile.dto';
import { UpdateQualityProfileDto } from './dto/update-quality-profile.dto';
import { CreateConfigItemDto } from './dto/create-config-item.dto';
import { UpdateConfigItemDto } from './dto/update-config-item.dto';

@ApiTags('Quality Profiles')
@Controller('quality-profiles')
export class QualityProfilesController {
  constructor(private readonly service: QualityProfilesService) {}

  // ── Profiles ────────────────────────────────────────────

  @Post()
  @ApiOperation({ summary: 'Create a new quality profile' })
  @ApiResponse({ status: 201, description: 'Profile created' })
  @ApiResponse({ status: 409, description: 'Profile name already exists' })
  create(@Body() dto: CreateQualityProfileDto) {
    return this.service.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List all quality profiles (with config items)' })
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get profile by ID (with config items and linked projects)' })
  @ApiResponse({ status: 404, description: 'Profile not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update profile' })
  @ApiResponse({ status: 404, description: 'Profile not found' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateQualityProfileDto,
  ) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete profile (projects will have profile unlinked)' })
  @ApiResponse({ status: 204, description: 'Profile deleted' })
  @ApiResponse({ status: 404, description: 'Profile not found' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.remove(id);
  }

  // ── Config Items ────────────────────────────────────────

  @Post(':id/configs')
  @ApiOperation({ summary: 'Add a config item to a profile' })
  @ApiResponse({ status: 201, description: 'Config item added' })
  addConfigItem(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateConfigItemDto,
  ) {
    return this.service.addConfigItem(id, dto);
  }

  @Get(':id/configs')
  @ApiOperation({ summary: 'List all config items of a profile' })
  getConfigItems(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.getConfigItems(id);
  }

  @Patch('configs/:itemId')
  @ApiOperation({ summary: 'Update a config item' })
  @ApiResponse({ status: 404, description: 'Config item not found' })
  updateConfigItem(
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateConfigItemDto,
  ) {
    return this.service.updateConfigItem(itemId, dto);
  }

  @Delete('configs/:itemId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a config item' })
  @ApiResponse({ status: 204, description: 'Config item deleted' })
  @ApiResponse({ status: 404, description: 'Config item not found' })
  removeConfigItem(@Param('itemId', ParseUUIDPipe) itemId: string) {
    return this.service.removeConfigItem(itemId);
  }
}
