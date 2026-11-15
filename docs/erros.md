# Tratamento de Erros

Todos os erros da FiscalAPI seguem o mesmo formato JSON:

```json
{
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "error": "CODIGO_DO_ERRO",
  "message": "Descricao legivel do erro"
}
```

## Codigos de Erro

### Autenticacao (HTTP 403)

| Codigo | Descricao |
|--------|-----------|
| `API_KEY_ERROR` | API key ausente, invalida ou revogada |
| `ACESSO_NEGADO` | Chave demo tentando acessar endpoint restrito |

### Parametros (HTTP 400)

| Codigo | Descricao |
|--------|-----------|
| `UF_NAO_SUPORTADA` | UF informada nao e suportada |
| `PARAMETRO_AUSENTE` | Documento obrigatorio nao informado |
| `PARAMETRO_CONFLITANTE` | Mais de um documento informado |
| `DOCUMENTO_INVALIDO` | CPF, CNPJ ou IE com formato invalido |
| `IE_NAO_SUPORTADO` | IE nao aceito neste endpoint (use CPF ou CNPJ) |

### Creditos (HTTP 402)

| Codigo | Descricao |
|--------|-----------|
| `LIMITE_ATINGIDO` | O saldo em creditos nao cobre a consulta, ou a conta nao tem plano nem creditos extras |

```json
{
  "error": "LIMITE_ATINGIDO",
  "usage": 500,
  "limit": 500,
  "plan": "starter",
  "extra_credits": 0,
  "cost": 1,
  "consultas_restantes": 0,
  "creditos": {"plano": 0.0, "extras": 0.0, "guardados": 0.0, "disponivel": 0.0},
  "preco": {"plano": 0.1, "extras": 0.12},
  "message": "Seu saldo do plano Starter não cobre esta consulta. Faça uma recarga no painel ou mude de plano para continuar."
}
```

| Campo | Descricao |
|-------|-----------|
| `consultas_restantes` | Quantas consultas deste tipo o saldo ainda paga |
| `creditos` | Saldo em creditos (1 credito = R$ 1): `plano` (creditos do plano que restam no ciclo), `extras` (creditos extras), `guardados` (de um plano que venceu; so voltam quando a conta assina um plano) e `disponivel` (`plano` + `extras`). Pode vir `null` |
| `preco` | Preco em R$ desta consulta: `plano` com os creditos do plano (`null` em conta sem plano) e `extras` com os creditos extras |
| `usage`, `limit`, `extra_credits`, `cost` | Mantidos por compatibilidade, na unidade antiga. Nao use para calcular o saldo |

Para ver o saldo sem esperar o 402: `GET /api/saldo` (nao cobra).

### Rate Limiting (HTTP 429)

| Codigo | Descricao |
|--------|-----------|
| `RATE_LIMIT_EXCEEDED` | Limite de requisicoes por minuto do plano excedido (Starter 20, Pro 60, Enterprise 120; conta sem plano, 5). Veja o header `Retry-After` |

### Fontes Externas (HTTP 502/503)

| Codigo | Descricao |
|--------|-----------|
| `PROCESSAMENTO_FALHOU` | Falha temporaria ao consultar a fonte oficial. Tente de novo |
| `SITE_INDISPONIVEL` | Portal da SEFAZ temporariamente fora do ar |
| `TODAS_FONTES_FALHARAM` | Nenhuma fonte de dados respondeu |

### Interno (HTTP 500)

| Codigo | Descricao |
|--------|-----------|
| `ERRO_INTERNO` | Erro inesperado no servidor |

## Boas Praticas

1. **Sempre verifique o `request_id`** — use-o para suporte e rastreamento
2. **Trate erros 502/503 com retry** — portais SEFAZ sao intermitentes
3. **Respeite o rate limit** — implemente backoff exponencial no 429
4. **Erros 400 sao definitivos** — nao faca retry, corrija o parametro

### Exemplo de Retry (Python)

```python
import time
import requests

def consultar_com_retry(url, headers, params, max_retries=3):
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers, params=params, timeout=90)

        if response.status_code == 429:
            wait = 2 ** attempt
            time.sleep(wait)
            continue

        if response.status_code in (502, 503):
            wait = 5 * (attempt + 1)
            time.sleep(wait)
            continue

        return response

    return response  # ultima tentativa
```
