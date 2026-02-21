import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QualityProfile } from './entities/quality-profile.entity';
import { QualityConfigItem } from './entities/quality-config-item.entity';
import { QualityProfilesService } from './quality-profiles.service';
import { QualityProfilesController } from './quality-profiles.controller';

@Module({
  imports: [TypeOrmModule.forFeature([QualityProfile, QualityConfigItem])],
  controllers: [QualityProfilesController],
  providers: [QualityProfilesService],
  exports: [QualityProfilesService],
})
export class QualityProfilesModule {}
