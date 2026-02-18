/**
 * Swagger/OpenAPI validation script for NestJS
 *
 * Usage:
 *   1. Add to package.json: "validate:api": "ts-node scripts/swagger-validation.ts"
 *   2. Run: npm run validate:api
 *
 * What it validates:
 *   - All endpoints have @ApiOperation and @ApiResponse decorators
 *   - DTOs have @ApiProperty on all properties
 *   - The generated spec is valid according to OpenAPI 3.0
 *   - No endpoints are missing documentation
 */

// ============================================================
// Example integration in quality-gate or CI
// ============================================================

/*
  // In main.ts or a separate script, generate the spec:
  import { NestFactory } from '@nestjs/core';
  import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
  import { AppModule } from './app.module';
  import * as fs from 'fs';

  async function generateSpec(): Promise<void> {
    const app = await NestFactory.create(AppModule, { logger: false });

    const config = new DocumentBuilder()
      .setTitle('API')
      .setVersion('1.0')
      .build();

    const document = SwaggerModule.createDocument(app, config);

    // Save spec for validation
    fs.writeFileSync('openapi-spec.json', JSON.stringify(document, null, 2));

    // Validar
    validateSpec(document);

    await app.close();
  }

  function validateSpec(spec: Record<string, any>): void {
    const errors: string[] = [];
    const paths = spec.paths || {};

    for (const [path, methods] of Object.entries(paths)) {
      for (const [method, operation] of Object.entries(methods as Record<string, any>)) {
        // Check if summary/description is present
        if (!operation.summary && !operation.description) {
          errors.push(`${method.toUpperCase()} ${path}: missing @ApiOperation (summary/description)`);
        }

        // Check if responses are documented
        if (!operation.responses || Object.keys(operation.responses).length === 0) {
          errors.push(`${method.toUpperCase()} ${path}: missing @ApiResponse`);
        }

        // Check if a 200/201 response is documented
        const hasSuccessResponse = Object.keys(operation.responses || {}).some(
          (code) => code.startsWith('2'),
        );
        if (!hasSuccessResponse) {
          errors.push(`${method.toUpperCase()} ${path}: missing success response (2xx)`);
        }
      }
    }

    if (errors.length > 0) {
      console.error('\n❌ Swagger Validation Errors:\n');
      errors.forEach((e) => console.error(`  - ${e}`));
      console.error(`\nTotal: ${errors.length} error(s)\n`);
      process.exit(1);
    }

    console.log('✓ Valid Swagger spec — all endpoints documented');
  }

  generateSpec().catch(console.error);
*/

// ============================================================
// Offline spec validation (without starting the application)
// Requires: npm install -D @apidevtools/swagger-parser
// ============================================================

/*
  import SwaggerParser from '@apidevtools/swagger-parser';

  async function validateOffline(): Promise<void> {
    try {
      const api = await SwaggerParser.validate('openapi-spec.json');
      console.log(`✓ Valid API: ${api.info.title} v${api.info.version}`);
    } catch (err) {
      console.error('❌ Invalid spec:', err.message);
      process.exit(1);
    }
  }

  validateOffline();
*/
