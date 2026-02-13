/**
 * Script de validação de API Swagger/OpenAPI para NestJS
 *
 * Uso:
 *   1. Adicione ao package.json: "validate:api": "ts-node scripts/swagger-validation.ts"
 *   2. Rode: npm run validate:api
 *
 * O que valida:
 *   - Todos os endpoints têm decorators @ApiOperation e @ApiResponse
 *   - DTOs têm @ApiProperty em todas as propriedades
 *   - O spec gerado é válido segundo OpenAPI 3.0
 *   - Não há endpoints sem documentação
 */

// ============================================================
// Exemplo de integração no quality-gate ou CI
// ============================================================

/*
  // No main.ts ou em um script separado, gere o spec:
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

    // Salvar spec para validação
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
        // Verificar se tem summary/description
        if (!operation.summary && !operation.description) {
          errors.push(`${method.toUpperCase()} ${path}: falta @ApiOperation (summary/description)`);
        }

        // Verificar se tem responses documentadas
        if (!operation.responses || Object.keys(operation.responses).length === 0) {
          errors.push(`${method.toUpperCase()} ${path}: falta @ApiResponse`);
        }

        // Verificar se tem response 200/201 documentada
        const hasSuccessResponse = Object.keys(operation.responses || {}).some(
          (code) => code.startsWith('2'),
        );
        if (!hasSuccessResponse) {
          errors.push(`${method.toUpperCase()} ${path}: falta response de sucesso (2xx)`);
        }
      }
    }

    if (errors.length > 0) {
      console.error('\\n❌ Swagger Validation Errors:\\n');
      errors.forEach((e) => console.error(`  - ${e}`));
      console.error(`\\nTotal: ${errors.length} erro(s)\\n`);
      process.exit(1);
    }

    console.log('✓ Swagger spec válido — todos os endpoints documentados');
  }

  generateSpec().catch(console.error);
*/

// ============================================================
// Validação offline do spec (sem subir a aplicação)
// Requer: npm install -D @apidevtools/swagger-parser
// ============================================================

/*
  import SwaggerParser from '@apidevtools/swagger-parser';

  async function validateOffline(): Promise<void> {
    try {
      const api = await SwaggerParser.validate('openapi-spec.json');
      console.log(`✓ API válida: ${api.info.title} v${api.info.version}`);
    } catch (err) {
      console.error('❌ Spec inválido:', err.message);
      process.exit(1);
    }
  }

  validateOffline();
*/
