# Consultar Simples Nacional

Consulta a situacao de um CNPJ no Simples Nacional (com a data da opcao), no SIMEI e nos regimes regulares de IBS e CBS, com os eventos futuros. Para filiais, a situacao e a da matriz.

**Endpoint:** `GET /api/consultar-simples-nacional`

## Parametros

| Parametro | Tipo | Obrigatorio | Descricao |
|-----------|------|-------------|-----------|
| `cnpj` | string | Sim | CNPJ da empresa (com ou sem formatacao) |

## Exemplo de Requisicao

```bash
curl -X GET "https://api.fiscalapi.com.br/api/consultar-simples-nacional?cnpj=11222333000181" \
  -H "X-API-Key: sua_api_key_aqui"
```

## Campos da Resposta

| Campo | Descricao |
|-------|-----------|
| `cnpj` | CNPJ consultado |
| `cnpj_matriz` | CNPJ da matriz (em filiais, a situacao mostrada e a dela) |
| `nome_empresarial` | Nome empresarial |
| `data_consulta` | Data da consulta |
| `situacao_simples` | Situacao no Simples Nacional |
| `optante_simples` | `true` se e optante |
| `data_opcao_simples` | Data da opcao (pode ser nula) |
| `situacao_simei` | Situacao no SIMEI |
| `enquadrado_simei` | `true` se esta enquadrado no SIMEI |
| `regime_regular_ibs` | Regime regular de IBS (Reforma Tributaria) |
| `regime_regular_cbs` | Regime regular de CBS (Reforma Tributaria) |
| `eventos_futuros` | Lista de `regime`, `descricao` e `data_efeito` |
| `mais_info` | Periodos anteriores de opcao e de enquadramento no SIMEI (pode ser nulo) |
| `cached` | `true` quando a resposta veio do cache (24 h) |

## Erros

| HTTP | Codigo | Significado |
|------|--------|-------------|
| 400 | `CNPJ_INVALIDO` | CNPJ invalido |
| 404 | `CNPJ_NAO_ENCONTRADO` | CNPJ nao encontrado na base da Receita Federal |
| 502 | `FONTE_INDISPONIVEL` | Fonte oficial indisponivel |
| 503 | `FONTE_TEMPORARIAMENTE_INDISPONIVEL`, `CONSULTA_EM_ANDAMENTO` | Tente de novo (header `Retry-After`) |
