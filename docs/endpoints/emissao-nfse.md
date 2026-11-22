# Emissao de NFS-e Nacional

A FiscalAPI emite a NFS-e do padrao nacional pela sua empresa. Voce manda os dados da nota em JSON; a FiscalAPI monta a DPS, confere as regras, assina com o **certificado A1 da propria empresa** e envia. A nota e processada em segundos e o resultado chega por webhook (ou pela consulta da nota).

- Cobra so a nota **autorizada em producao**. Rejeitada, cancelamento e homologacao nao cobram.
- Homologacao gratis, ate 1.000 notas por mes, para testar a integracao.
- Dado faltando ou incoerente volta `422` com o campo, antes do envio.
- XML e DANFSe (PDF) de cada nota autorizada, sem custo.

Documentacao completa (todos os campos, presets, IBS/CBS e erros): [docs.fiscalapi.com.br/docs/emissao-nfse/visao-geral](https://docs.fiscalapi.com.br/docs/emissao-nfse/visao-geral).

## Rotas

Base: `https://api.fiscalapi.com.br/api/nfse`

| Rota | O que faz |
|------|-----------|
| `PUT /certificados` | Envia ou renova o certificado A1 (`multipart/form-data`: `certificado` e `senha`) |
| `DELETE /certificados/{raiz}` | Exclui o certificado de uma raiz de CNPJ (`204`) |
| `POST /empresas` | Cadastra a empresa emissora (`201`) |
| `GET /empresas` | Lista as empresas da conta |
| `GET /empresas/{id}` | Consulta uma empresa |
| `PATCH /empresas/{id}` | Edita razao social, IM, municipio, regime ou `ativa` |
| `POST /notas` | Emite a NFS-e (`202`, nota `pendente`) |
| `GET /notas/{id}` | Consulta a nota |
| `GET /notas` | Lista as notas, com cursor |
| `GET /notas/{id}/xml` | XML da nota autorizada |
| `GET /notas/{id}/pdf` | DANFSe em PDF |
| `POST /notas/{id}/cancelamento` | Pede o cancelamento (`202`) |
| `POST /notas/{id}/substituicao` | Substitui por uma nota nova (`202`) |
| `POST /notas/{id}/webhook` | Reenvia os avisos de uma nota |
| `PUT /webhook` | Configura o webhook e devolve o `segredo` (so no primeiro cadastro) |
| `GET /webhook` | Consulta o webhook |
| `DELETE /webhook` | Remove o webhook (`204`) |

A chave de homologacao (`fapi_test_...`) so usa as rotas de notas, e so com `ambiente: "homologacao"`. Certificados, empresas e webhook ficam com a chave de producao.

## Primeira nota

Os exemplos usam a empresa ficticia **11.222.333/0001-81**, em Curitiba (IBGE `4106902`), optante do Simples (ME/EPP). Troque pelos dados da sua empresa.

### 1. Envie o certificado

Certificado **A1** (e-CNPJ ICP-Brasil), `.pfx` de ate 100 KB, da mesma raiz (8 primeiros digitos) do CNPJ que vai emitir. Um certificado serve para a matriz e as filiais.

```bash
curl -X PUT "https://api.fiscalapi.com.br/api/nfse/certificados" \
  -H "X-API-Key: sua_api_key_aqui" \
  -F "certificado=@empresa.pfx" \
  -F "senha=senha-do-certificado"
```

A API confere a senha, a validade, o titular e a cadeia ICP-Brasil. Recusa: `422` `NFSE_CERTIFICADO_INVALIDO`, com o motivo em `causa` (`SENHA_INCORRETA`, `VENCIDO`, `FORA_DA_ICP_BRASIL`...). O arquivo e a senha nunca voltam.

### 2. Cadastre a empresa

```bash
curl -X POST "https://api.fiscalapi.com.br/api/nfse/empresas" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{
    "cnpj": "11.222.333/0001-81",
    "razao_social": "Exemplo Servicos de Tecnologia Ltda",
    "im": "123456",
    "cod_mun_ibge": "4106902",
    "regime": {"op_simp_nac": 3, "reg_ap_trib_sn": 1},
    "serie": "00001"
  }'
```

Guarde o `id` da resposta: ele vai em cada nota.

| Campo | Descricao |
|-------|-----------|
| `regime.op_simp_nac` | `1` nao optante, `2` MEI, `3` ME/EPP |
| `regime.reg_ap_trib_sn` | So para ME/EPP, e obrigatorio nele: `1`, `2` ou `3` |
| `serie` | Serie da DPS, de `00001` a `49999` |
| `primeiro_ndps_producao` | Para continuar a numeracao de outro sistema: acima do ultimo numero usado |

A numeracao da DPS e automatica. `convenio_ok: false` (aviso `MUNICIPIO_SEM_CONVENIO`) indica que o municipio pode nao emitir pelo padrao nacional.

### 3. Configure o webhook

```bash
curl -X PUT "https://api.fiscalapi.com.br/api/nfse/webhook" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{"url": "https://seu-sistema.com.br/webhooks/nfse"}'
```

O `segredo` (`whsec_...`) vem so no primeiro cadastro: guarde-o. Chamar de novo troca a URL e mantem o segredo. Um webhook por conta, para os dois ambientes. So `https` na porta 443, com nome publico.

### 4. Emita em homologacao

```bash
curl -X POST "https://api.fiscalapi.com.br/api/nfse/notas" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{
    "empresa_id": "8f1c2a4e-5b6d-4e7f-9a0b-1c2d3e4f5a6b",
    "ambiente": "homologacao",
    "referencia": "teste-0001",
    "preset": "simples_servico",
    "competencia": "2026-11-22",
    "tomador": {"tipo": "cnpj", "documento": "12.345.678/0001-95", "nome": "Cliente Exemplo Comercio Ltda"},
    "servico": {"codigo_tributacao_nacional": "01.07.01", "descricao": "Suporte tecnico em informatica, novembro de 2026"},
    "valores": {"valor_servico": "1500.00", "percentual_tributos_aproximado": "6.00"}
  }'
```

Resposta `202` (resumida):

```json
{
  "id": "3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b",
  "status": "pendente",
  "ambiente": "homologacao",
  "referencia": "teste-0001",
  "chave_acesso": null,
  "numero_nfse": null,
  "avisos": [
    {"codigo": "R008", "campo": "ibs_cbs", "mensagem": "informe ibs_cbs: sera obrigatorio para o Simples a partir de 2027-01-01"}
  ]
}
```

`avisos` nao impedem a emissao. Mande valores como texto (`"1500.00"`).

| Campo | Descricao |
|-------|-----------|
| `ambiente` | `homologacao` (sem valor fiscal) ou `producao` |
| `referencia` | O seu id do pedido, ate 50 caracteres. **Obrigatoria em producao** (ou o cabecalho `Idempotency-Key`) |
| `preset` | `simples_servico`, `regime_normal_servico` ou `locacao_bem_movel` |
| `tomador` | `tipo` (`cpf`, `cnpj`, `estrangeiro`, `nao_identificado`), `documento`, `nome`, `email`, `endereco` |
| `servico` | `codigo_tributacao_nacional` (6 digitos) e `descricao` |
| `valores` | `valor_servico`, `iss`, e os tributos aproximados do regime |

Tributos aproximados: ME/EPP manda `percentual_tributos_aproximado`; nao optante, `tributos_aproximados` (`federal`, `estadual`, `municipal`); MEI, nenhum.

### 5. Receba o resultado e baixe os arquivos

Em segundos, o webhook recebe o evento `autorizada` (ou `rejeitada`). Sem webhook, consulte:

```bash
curl "https://api.fiscalapi.com.br/api/nfse/notas/3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b" \
  -H "X-API-Key: sua_api_key_aqui"

curl "https://api.fiscalapi.com.br/api/nfse/notas/3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b/pdf" \
  -H "X-API-Key: sua_api_key_aqui" -o danfse.pdf

curl "https://api.fiscalapi.com.br/api/nfse/notas/3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b/xml" \
  -H "X-API-Key: sua_api_key_aqui" -o nfse.xml
```

Autorizada, a nota traz `chave_acesso` (50 digitos) e `numero_nfse`. Rejeitada, traz `erros` com `codigo` e `descricao`; corrija e envie de novo com a mesma `referencia`.

### 6. Passe para producao

1. Troque `"ambiente": "homologacao"` por `"producao"`.
2. Mande sempre a `referencia`. O mesmo pedido com a mesma referencia devolve a nota que ja existe (`Idempotent-Replayed: true`), sem emitir outra. Referencia repetida com dados diferentes: `409` `NFSE_REFERENCIA_EM_USO`.
3. Tenha plano ou creditos: a nota autorizada e cobrada.
4. No webhook, filtre pelo campo `ambiente`.

## Situacoes da nota

| `status` | O que significa |
|----------|-----------------|
| `pendente` | Na fila |
| `processando` | Sendo enviada |
| `autorizada` | Autorizada: tem `chave_acesso`, `numero_nfse`, XML e DANFSe |
| `rejeitada` | Recusada: motivo em `erros`. Nao cobra e libera a `referencia` |
| `cancelando` | Pedido de cancelamento em andamento |
| `cancelada` | Cancelada |
| `substituida` | Trocada por outra nota (`substituida_por_id`) |

## Sincronizar

`GET /api/nfse/notas?ambiente=producao&atualizada_desde=2026-11-22T00:00:00-03:00&limite=100` devolve as notas em ordem de `updated_at`. Passe o `proximo` em `cursor` ate ele vir `null`. Guarde o `updated_at` da ultima nota e peca `atualizada_desde` a partir dele; a nota do proprio instante volta de novo, trate pelo `id`. Filtros: `status`, `ambiente`, `referencia`, `atualizada_desde`, `limite` (ate 100).

## Cancelar e substituir

```bash
curl -X POST "https://api.fiscalapi.com.br/api/nfse/notas/3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b/cancelamento" \
  -H "X-API-Key: sua_api_key_aqui" -H "Content-Type: application/json" \
  -d '{"motivo": 1, "justificativa": "Valor do servico informado errado na nota."}'
```

- Cancelamento: `motivo` `1` (erro na emissao), `2` (servico nao prestado) ou `9` (outros) e `justificativa` de 15 a 255 caracteres. A nota fica `cancelando`; depois `cancelada` ou, se recusado, volta a `autorizada` com o motivo em `erros` (evento `cancelamento_recusado`).
- Substituicao: mesmo corpo da emissao (sem `empresa_id`, `ambiente` e `preset`), mais `motivo` (`01` a `05` ou `99`), `justificativa` (obrigatoria com `99`) e a `referencia` da nota **nova**. A resposta e a nota nova, com `substitui_id`. Autorizada, chegam os avisos `autorizada` (nova) e `substituida` (original).

## Aviso no webhook

POST JSON com os cabecalhos:

| Cabecalho | Valor |
|-----------|-------|
| `X-FiscalAPI-Evento` | `autorizada`, `rejeitada`, `cancelada`, `substituida` ou `cancelamento_recusado` |
| `X-FiscalAPI-Entrega` | Id da entrega: um por nota e evento |
| `X-FiscalAPI-Timestamp` | Segundos Unix do envio |
| `X-FiscalAPI-Assinatura` | `v1=<hex>` |

O corpo tem os campos da consulta da nota, mais `evento`:

```json
{
  "id": "3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b",
  "status": "autorizada",
  "ambiente": "producao",
  "referencia": "pedido-1001",
  "empresa_id": "8f1c2a4e-5b6d-4e7f-9a0b-1c2d3e4f5a6b",
  "chave_acesso": "41069022211222333000181000000000004226111048219373",
  "numero_nfse": "42",
  "erros": null,
  "autorizada_em": "2026-11-22T13:05:04Z",
  "updated_at": "2026-11-22T13:05:04Z",
  "evento": "autorizada"
}
```

Responda `2xx` em ate 10 s e processe depois. A entrega e "pelo menos uma vez" e sem ordem garantida: deduplique pelo par `X-FiscalAPI-Entrega` + `updated_at`. Sem `2xx`, novas tentativas por ate 24 horas; `POST /api/nfse/notas/{id}/webhook` reenvia os avisos de uma nota.

## Verificar a assinatura

O esquema e o mesmo do [Monitor de NF-e](monitor-nfe.md#verificar-a-assinatura), e o mesmo codigo serve: `v1=` + HMAC-SHA256 em hex, com o segredo inteiro (`whsec_...`) como chave, sobre `"{timestamp}." + corpo_bruto`. Use o corpo bruto, compare em tempo constante e recuse timestamp com mais de 5 minutos de diferenca.

Os SDKs oficiais (versao 0.7.0 ou superior) trazem a verificacao e os metodos da emissao: [Python](https://github.com/fiscalapi-br/fiscalapi-python) (`emitir_nfse`, `verificar_assinatura`), [Node.js](https://github.com/fiscalapi-br/fiscalapi-node) (`emitirNfse`, `verificarAssinaturaWebhook`) e [PHP](https://github.com/fiscalapi-br/fiscalapi-php) (`emitirNfse`, `Webhook::verificarAssinatura`).

Vetor para testar sua implementacao (passe `agora = 1795439400`):

| Item | Valor |
|------|-------|
| Segredo | `whsec_RXhlbXBsbyBkZSBzZWdyZWRvLCBuYW8gdXNlIGVtIHByb2R1Y2Fv` |
| Timestamp | `1795439400` |
| Corpo | `{"id":"3b8e2f4a-6c1d-4e9f-8a7b-2c3d4e5f6a7b","status":"autorizada","ambiente":"homologacao","evento":"autorizada"}` |
| Assinatura esperada | `v1=0c95c6c219de4c9a004efd0b8896f1e8e0d36bd373d86eb859f65506d5c0b9ed` |

## Cobranca

Por nota **autorizada em producao**, uma vez:

| Plano | Com creditos do plano | Com creditos extras |
|-------|-----------------------|---------------------|
| Starter | R$ 0,15 | R$ 0,18 |
| Pro | R$ 0,10 | R$ 0,12 |
| Enterprise | R$ 0,07 | R$ 0,07 |

Nao cobram: nota rejeitada, o pedido de cancelamento (a nota cancelada continua cobrada, sem estorno), notas de homologacao, consultar, listar, XML, DANFSe, empresas, certificados e webhook. A substituicao gera uma nota nova, cobrada quando for autorizada.

## Erros

Formato RFC 7807, com o codigo em `title`. Os principais:

| HTTP | Codigo | Significado |
|------|--------|-------------|
| 402 | `LIMITE_ATINGIDO` | Saldo insuficiente em producao (`notas_a_cobrar` diz quantas ainda vao ser cobradas) |
| 403 | `NFSE_TERMOS_PENDENTES` | Aceite os Termos atualizados no painel para continuar emitindo |
| 403 | `NFSE_AMBIENTE_DA_CHAVE` | Chave de homologacao pedindo `producao` |
| 403 | `NFSE_EMPRESA_NAO_VERIFICADA` | Empresa sem posse do CNPJ conferida: desative e religue |
| 404 | `NFSE_EMPRESA_NAO_ENCONTRADA` / `NFSE_NOTA_NAO_ENCONTRADA` | Id de outra conta, inexistente ou desativado |
| 409 | `NFSE_CERTIFICADO_AUSENTE` | Envie o certificado da raiz antes de cadastrar a empresa |
| 409 | `NFSE_REFERENCIA_EM_USO` | Referencia ja usada com outros dados |
| 409 | `NFSE_NAO_CANCELAVEL` / `NFSE_NAO_SUBSTITUIVEL` | So nota `autorizada` |
| 409 | `NFSE_NOTA_SEM_XML` | A nota ainda nao foi autorizada |
| 422 | `NFSE_DADOS_INVALIDOS` | Corrija os campos listados em `erros` |
| 422 | `NFSE_CERTIFICADO_INVALIDO` | Certificado recusado: motivo em `causa` |
| 429 | `NFSE_HOMOLOG_LIMITE` | Passou das 1.000 notas de homologacao do mes |
| 429 | `RATE_LIMIT_EXCEEDED` | Limite por minuto (`Retry-After`) |

Tabela completa: [docs.fiscalapi.com.br/docs/emissao-nfse/erros](https://docs.fiscalapi.com.br/docs/emissao-nfse/erros).

## O que a v1 nao faz

- Emissao por procuracao ou com certificado de outra raiz (escritorio contabil emitindo pelo cliente).
- Emissao manual pelo painel (o painel acompanha as notas; a emissao e pela API).
- Nota Fiscal Paulistana e outros emissores municipais fora do padrao nacional.
- Imunidade e exportacao de servico (`iss.tributacao` 2 e 3), compra governamental e documentos referenciados.
