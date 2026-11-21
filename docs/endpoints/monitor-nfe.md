# Monitor de NF-e por chave

Voce cadastra chaves de NF-e (modelo 55) e a FiscalAPI acompanha cada nota na SEFAZ por ate 180 dias. Quando a nota e cancelada, denegada ou recebe um evento (carta de correcao, por exemplo), chega um aviso assinado no seu webhook. Sem certificado. Todas as 27 UFs.

## Rotas

| Rota | O que faz | Cobra |
|------|-----------|-------|
| `POST /api/monitor-nfe/chaves` | Coloca ate 1.000 chaves no monitor | Por chave aceita, uma vez |
| `POST /api/monitor-nfe/chaves/remover` | Para de monitorar ate 1.000 chaves (sem estorno) | Nao |
| `DELETE /api/monitor-nfe/chaves/{chave}` | Para de monitorar uma chave (`204`) | Nao |
| `GET /api/monitor-nfe/chaves` | Lista as chaves, com cursor | Nao |
| `GET /api/monitor-nfe/chaves/{chave}` | Situacao, eventos, proxima verificacao e avisos que falharam | Nao |
| `PUT /api/monitor-nfe/webhook` | Cadastra ou troca a URL do webhook e devolve o `segredo` | Nao |
| `GET /api/monitor-nfe/webhook` | URL cadastrada e se os avisos estao saindo | Nao |
| `DELETE /api/monitor-nfe/webhook` | Remove o webhook (o monitoramento continua) | Nao |
| `POST /api/monitor-nfe/webhook/rotacionar-segredo` | Gera segredo novo; o anterior vale por mais 24 h | Nao |
| `POST /api/monitor-nfe/webhook/teste` | Envia um aviso `tipo: teste` (`202`) | Nao |

## 1. Cadastre o webhook

```bash
curl -X PUT "https://api.fiscalapi.com.br/api/monitor-nfe/webhook" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{"url": "https://seu-sistema.com.br/fiscalapi/avisos"}'
```

```json
{ "url": "https://seu-sistema.com.br/fiscalapi/avisos", "segredo": "whsec_..." }
```

O `segredo` so aparece aqui e na rotacao: guarde-o. A URL precisa ser `https` na porta 443, com nome publico (sem IP nem endereco interno) e sem redirecionamento. Cadastrar de novo gera outro segredo e reativa o webhook. Ate 10 cadastros e 10 testes por hora.

## 2. Cadastre as chaves

```bash
curl -X POST "https://api.fiscalapi.com.br/api/monitor-nfe/chaves" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{"chaves": [{"chave": "35261111222333000181550010000001231123456787"}], "prazo_dias": 180}'
```

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `chaves[].chave` | Sim | Chave de acesso (44 digitos); separadores sao ignorados |
| `chaves[].status_conhecido` | Nao | Situacao que voce ja conhece (padrao `autorizada`). O primeiro aviso so sai se a situacao atual for diferente |
| `prazo_dias` | Nao | De 1 a 180 (padrao 180) |

```json
{
  "resultados": [
    { "chave": "35261111222333000181550010000001231123456787", "situacao": "aceita", "motivo": null, "encerra_em": "2027-05-20T14:00:00-03:00" }
  ],
  "aceitas": 1,
  "valor_cobrado": "0,03"
}
```

`situacao` por chave, na mesma ordem do pedido: `aceita` (cobrada), `ja_monitorada` (sem nova cobranca) ou `invalida` (com `motivo`, sem cobranca). Chave com mais de 180 dias da emissao volta `invalida`. Sem saldo para todas as aceitas: `402` e nenhuma chave entra.

## 3. Acompanhe

- `GET /api/monitor-nfe/chaves?ativo=true&limite=100`: passe o `proximo_cursor` em `cursor` ate ele vir `null`. Filtros: `status`, `ativo`, `alterado_desde`, `limite` (ate 1.000).
- `alterado_desde` busca o que mudou desde a ultima leitura (util se algum aviso se perdeu). A busca volta 5 minutos antes do instante pedido: itens podem repetir, deduplique por `chave` + `atualizada_em`.
- `entregas_falhas` em cada item conta os avisos que o webhook nao recebeu; o detalhe (`GET /api/monitor-nfe/chaves/{chave}`) lista quais em `entregas_que_falharam`.

Situacoes da nota: `autorizada`, `autorizada_fora_prazo`, `denegada`, `cancelada`, `cancelada_fora_prazo`, `nao_encontrada` e `chave_divergente` (a chave nao bate com a nota guardada na SEFAZ: sinal de DANFE adulterado).

A primeira verificacao e no cadastro; depois em 1 h, 6 h, 25 h, 72 h e 168 h apos a autorizacao, e entao toda semana ate o fim do prazo.

## Aviso no webhook

POST JSON com os cabecalhos:

| Cabecalho | Valor |
|-----------|-------|
| `X-FiscalAPI-Evento-Id` | Mesmo `id` do corpo |
| `X-FiscalAPI-Timestamp` | Segundos Unix do envio |
| `X-FiscalAPI-Assinatura` | `v1=<hex>`; na troca de segredo, `v1=nova,v1=anterior` por 24 h |

```json
{
  "id": "evt_0123456789abcdef0123456789abcdef",
  "tipo": "nfe.status_alterado",
  "ocorrido_em": "2026-11-22T09:12:40-03:00",
  "chave": "35261111222333000181550010000001231123456787",
  "status_anterior": "autorizada",
  "status_atual": "cancelada",
  "evento": {
    "tipo": "cancelamento",
    "codigo": "110111",
    "sequencia": 1,
    "protocolo": "135260000000001",
    "registrado_em": "2026-11-22T08:55:03-03:00",
    "texto": "Pedido cancelado pelo cliente antes do envio"
  },
  "monitoramento": { "ativo": false, "encerra_em": "2027-05-20T14:00:00-03:00", "motivo_encerramento": "cancelada" }
}
```

Tipos: `nfe.status_alterado` (o cancelamento vem aqui, um aviso so), `nfe.evento_registrado` (carta de correcao, EPEC e outros), `nfe.monitoramento_encerrado` (fim do prazo, nota nao encontrada, fora dos 180 dias da SEFAZ) e `teste` (so `id`, `tipo` e `ocorrido_em`).

Responda `2xx` em ate 10 s. Sem `2xx`, o aviso e reenviado em 1 min, 5 min, 30 min, 2 h, 6 h, 12 h e 24 h; depois fica em `entregas_falhas`. Com 3 dias seguidos de falha, o webhook e desativado (`GET /api/monitor-nfe/webhook` mostra `ativo: false`) e voce recebe um e-mail; cadastre de novo para reativar. A entrega e "pelo menos uma vez": deduplique pelo `id`.

## Verificar a assinatura

`X-FiscalAPI-Assinatura` = `v1=` + HMAC-SHA256 em hex, com o segredo inteiro (`whsec_...`) como chave, sobre `"{timestamp}." + corpo_bruto`.

1. Use o corpo **bruto**, exatamente os bytes recebidos (nao o JSON reinterpretado).
2. Aceite se qualquer `v1=` bater (na troca de segredo vem duas).
3. Compare em tempo constante.
4. Recuse timestamp com mais de 5 minutos de diferenca do seu relogio.

Python (Flask):

```python
import hashlib, hmac, os, time
from flask import Flask, request

app = Flask(__name__)
SEGREDO = os.environ["FISCALAPI_WEBHOOK_SEGREDO"]

@app.post("/fiscalapi/avisos")
def avisos():
    corpo = request.get_data()
    ts = request.headers.get("X-FiscalAPI-Timestamp", "")
    assinaturas = [p.strip()[3:] for p in request.headers.get("X-FiscalAPI-Assinatura", "").split(",")
                   if p.strip().startswith("v1=")]
    if not (ts.isascii() and ts.isdigit()) or abs(time.time() - int(ts)) > 300:
        return "", 401
    esperada = hmac.new(SEGREDO.encode(), f"{ts}.".encode() + corpo, hashlib.sha256).hexdigest()
    if not any(hmac.compare_digest(esperada.encode(), a.encode()) for a in assinaturas):
        return "", 401
    aviso = request.get_json()
    # deduplique por aviso["id"] e processe
    return "", 200
```

Node.js (Express):

```js
const crypto = require('crypto');
const express = require('express');
const app = express();

app.post('/fiscalapi/avisos', express.raw({ type: 'application/json' }), (req, res) => {
  const ts = req.get('X-FiscalAPI-Timestamp') || '';
  const assinaturas = (req.get('X-FiscalAPI-Assinatura') || '')
    .split(',').map((p) => p.trim()).filter((p) => p.startsWith('v1=')).map((p) => p.slice(3));
  if (!/^\d+$/.test(ts) || Math.abs(Date.now() / 1000 - Number(ts)) > 300) return res.sendStatus(401);
  const esperada = crypto.createHmac('sha256', process.env.FISCALAPI_WEBHOOK_SEGREDO)
    .update(Buffer.concat([Buffer.from(`${ts}.`), req.body])).digest('hex');
  const ok = assinaturas.some((a) => /^[0-9a-f]{64}$/.test(a) &&
    crypto.timingSafeEqual(Buffer.from(a), Buffer.from(esperada)));
  if (!ok) return res.sendStatus(401);
  const aviso = JSON.parse(req.body.toString('utf8'));
  // deduplique por aviso.id e processe
  res.sendStatus(200);
});
```

Os SDKs oficiais ja trazem a verificacao: `verificar_assinatura` ([Python](https://github.com/fiscalapi-br/fiscalapi-python)), `verificarAssinaturaWebhook` ([Node.js](https://github.com/fiscalapi-br/fiscalapi-node)) e `Webhook::verificarAssinatura` ([PHP](https://github.com/fiscalapi-br/fiscalapi-php)).

Vetor para testar sua implementacao:

| Item | Valor |
|------|-------|
| Segredo | `whsec_dGVzdGUtZG8tc2RrLWZpc2NhbGFwaQ` |
| Timestamp | `1795294800` |
| Corpo | `{"id":"evt_0123456789abcdef0123456789abcdef","tipo":"teste","ocorrido_em":"2026-11-21T17:00:00-03:00"}` |
| Assinatura esperada | `v1=8b03e794ca99a1c2c684cf54191aae0af0f7d4e696ef598f9258365861fa8933` |

## Cobranca

Por chave aceita, uma vez, cobrindo todo o acompanhamento: R$ 0,03 (Starter), R$ 0,02 (Pro) e R$ 0,015 (Enterprise), com os creditos do plano ou com creditos extras. Chave ja monitorada e chave invalida nao sao cobradas. Remover nao estorna. Listar, consultar e o webhook nao cobram.

## Erros

| HTTP | Codigo | Significado |
|------|--------|-------------|
| 402 | `LIMITE_ATINGIDO` | O saldo nao cobre todas as chaves aceitas; nenhuma entrou |
| 403 | `API_KEY_ERROR` | Chave de API ausente, invalida ou revogada |
| 404 | `MONITORAMENTO_NAO_ENCONTRADO` | A chave nao esta no monitor da conta |
| 404 | `WEBHOOK_NAO_CADASTRADO` | Nenhum webhook cadastrado |
| 409 | `WEBHOOK_INATIVO` | Teste com o webhook desativado por falhas: cadastre de novo |
| 422 | `PARAMETRO_INVALIDO`, `URL_RECUSADA`, `CURSOR_INVALIDO` | Lote fora de 1 a 1.000, prazo fora de 1 a 180, URL nao aceita ou cursor que nao veio da API |
| 429 | `RATE_LIMIT_EXCEEDED` | Limite por minuto do plano (`Retry-After`) |
| 503 | `MONITOR_INDISPONIVEL` | Tente de novo em instantes |
