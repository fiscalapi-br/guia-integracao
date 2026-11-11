# Consultar NFS-e por chave

Consulta uma NFS-e do padrao nacional pela chave de acesso (50 digitos), sem certificado digital. Retorna emitente, tomador, servico, tributacao municipal e federal e a situacao de geracao.

**Endpoint:** `GET /api/consultar-nfse`

## Parametros

| Parametro | Tipo | Obrigatorio | Descricao |
|-----------|------|-------------|-----------|
| `chave` | string | Sim | Chave de acesso da NFS-e (50 digitos) |
| `danfse` | boolean | Nao | `true` inclui o PDF do DANFSe em base64 (`danfse_pdf_base64`) |

## Exemplo de Requisicao

```bash
curl -X GET "https://api.fiscalapi.com.br/api/consultar-nfse?chave=35503082211222333000181000000000012326100000045676" \
  -H "X-API-Key: sua_api_key_aqui"
```

Uma consulta nova leva de 30 a 60 segundos: use timeout de pelo menos 100 s (a consulta e encerrada em 95 s). A mesma chave consultada de novo em ate 24 h volta do cache na hora (`cached: true`) e tambem e cobrada.

## Campos da Resposta

| Campo | Descricao |
|-------|-----------|
| `chave`, `numero_nfse`, `codigo_municipio_emissor` | Identificacao da nota |
| `data_geracao`, `versao`, `dps` | Geracao e DPS (`numero`, `serie`, `data_emissao`) |
| `situacao` | `codigo` e `descricao`: 100 gerada, 101 de substituicao, 102 por decisao judicial, 103 avulsa. **Nao indica cancelamento** |
| `emitente`, `tomador`, `intermediario` | Partes da nota |
| `servico` | Municipio, codigo de tributacao nacional e descricao |
| `tributacao_municipal` | ISSQN: valor do servico, base de calculo, `aliquota` (percentual, 2.5 = 2,5%), `valor_issqn` |
| `tributacao_federal` | PIS, COFINS, IRRF e contribuicoes retidas |
| `total_tributos` | Lista de `descricao` e `valor` |
| `cached` | `true` quando veio do cache |
| `danfse_pdf_base64` | PDF do DANFSe (so com `danfse=true`) |
| `aviso` | Presente quando o PDF pedido nao pode ser obtido |

Campo ausente na nota vem `null`.

## Cobranca

Mesmo preco do XML de NF-e sem certificado, so quando a NFS-e e entregue. Chave invalida, nota nao encontrada e falha nao sao cobradas. Entra nas 10 consultas gratis do mes da conta que nunca assinou (gasta 1 das 10).

## Erros

| HTTP | Codigo | Significado |
|------|--------|-------------|
| 400 | `PARAMETRO_AUSENTE`, `CHAVE_INVALIDA` | Chave ausente ou invalida |
| 402 | — | Saldo insuficiente |
| 404 | `NFSE_NAO_ENCONTRADA` | NFS-e nao encontrada para a chave |
| 429 | `CONSULTAS_SIMULTANEAS` | Mais de 2 consultas em andamento na conta (`Retry-After`) |
| 502 | `FONTE_INDISPONIVEL` | Fonte oficial indisponivel |
| 503 | `FONTE_TEMPORARIAMENTE_INDISPONIVEL`, `CONSULTA_EM_ANDAMENTO` | Tente de novo (`Retry-After`) |
