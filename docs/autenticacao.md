# Autenticacao

Todas as requisicoes a API FiscalAPI exigem autenticacao via API Key.

## Obtendo sua API Key

1. Crie uma conta em [app.fiscalapi.com.br](https://app.fiscalapi.com.br)
2. Confirme o e-mail. Pela API, toda consulta pede plano (a partir do Lite, R$ 19,99/mes) ou saldo de recarga. As 10 consultas gratis do mes sao so no painel: teste la antes de assinar
3. No painel, abra **Chave API** e clique em **Gerar nova chave API**
4. Copie a chave — ela so e exibida uma vez

## Usando a API Key

Envie a chave no header `X-API-Key` de cada requisicao:

```bash
curl -X GET "https://api.fiscalapi.com.br/api/consultar?uf=MT&cpf=12345678909" \
  -H "X-API-Key: fapi_sua_chave_aqui"
```

## Formato da Chave

A chave comeca com `fapi_`, seguido de 64 caracteres hexadecimais. Ha uma chave ativa por conta; gerar outra revoga a anterior.

## Testar sem chave

- Consulta de IE no site [fiscalapi.com.br](https://fiscalapi.com.br): resultado real, com dados mascarados, sem cadastro
- Conta sem plano: 10 consultas gratis por mes so no painel, sem cartao. Pela API, plano ou recarga

## Erros de Autenticacao

| Codigo | Erro | Descricao |
|--------|------|-----------|
| 403 | `API_KEY_ERROR` | Chave ausente, invalida ou revogada |

## Boas Praticas

- **Nunca exponha sua API key no frontend** — faca chamadas pelo backend
- **Use variaveis de ambiente** para armazenar a chave
- **Gere uma nova chave no painel se ela vazar**: a anterior deixa de funcionar na hora

```python
import os

API_KEY = os.environ["FISCALAPI_KEY"]
```

```javascript
const API_KEY = process.env.FISCALAPI_KEY;
```

```php
$apiKey = getenv('FISCALAPI_KEY');
```
