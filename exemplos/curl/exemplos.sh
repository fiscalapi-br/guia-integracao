#!/bin/bash
# FiscalAPI — Exemplos com cURL
# https://fiscalapi.com.br
#
# Configure sua API key:
#   export FISCALAPI_KEY="sua_api_key_aqui"

API_KEY="${FISCALAPI_KEY:?Defina FISCALAPI_KEY}"
BASE_URL="https://api.fiscalapi.com.br"

echo "=== Consulta IE em MT por CPF ==="
curl -s -X GET "${BASE_URL}/api/consultar?uf=MT&cpf=12345678909" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Consulta IE em Todos os Estados ==="
curl -s -X GET "${BASE_URL}/api/consultar-ie-todos?cpf=12345678909" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Consulta CNPJ na Receita Federal ==="
curl -s -X GET "${BASE_URL}/api/consultar-cnpj?cnpj=12345678000195" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Situacao no Simples Nacional ==="
curl -s -X GET "${BASE_URL}/api/consultar-simples-nacional?cnpj=11222333000181" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== NFS-e por chave (leva de 30 a 60 s) ==="
curl -s -m 120 -X GET "${BASE_URL}/api/consultar-nfse?chave=35503082211222333000181000000000012326100000045676" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== CND Estadual em MT ==="
curl -s -X GET "${BASE_URL}/api/consultar-cnd?uf=MT&cnpj=12345678000195" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== CND em Todos os Estados ==="
curl -s -X GET "${BASE_URL}/api/consultar-cnd-todos?cnpj=12345678000195" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Consulta CNIR/CAFIR ==="
curl -s -X GET "${BASE_URL}/api/consultar-cnir?cpf=12345678909" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Monitor de NF-e: chaves monitoradas (nao cobra) ==="
curl -s -X GET "${BASE_URL}/api/monitor-nfe/chaves?ativo=true&limite=10" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool

echo ""
echo "=== Emissao de NFS-e: notas emitidas (nao cobra) ==="
curl -s -X GET "${BASE_URL}/api/nfse/notas?limite=10" \
  -H "X-API-Key: ${API_KEY}" | python3 -m json.tool
