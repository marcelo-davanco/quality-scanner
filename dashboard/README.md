# Quality Scanner Dashboard

Dashboard web para visualizar os resultados do Quality Scanner.

## Configuração

Copie `.env.local` e ajuste conforme necessário:

| Variável | Descrição | Default |
|---|---|---|
| `REPORTS_PATH` | Caminho para o diretório de reports (relativo ou absoluto) | `../reports` |
| `NEXT_PUBLIC_SONAR_URL` | URL pública do SonarQube (para links clicáveis) | `http://localhost:9000` |
| `PORT` | Porta do dashboard | `3000` |

## Executar

```bash
npm install
npm run dev
```

Abra [http://localhost:3000](http://localhost:3000) no navegador.

## Funcionalidades

- **Histórico** — sidebar com scans agrupados por data
- **Resumo** — cards com contagem de passed/failed/warnings/skipped
- **Ferramentas** — cards com expand/collapse para detalhes de cada ferramenta
- **SonarQube** — métricas, condições do quality gate e link direto para o dashboard do SQ
- **Jest** — cobertura por categoria e por arquivo, testes falhando
- **ESLint** — issues agrupados por regra com ocorrências

