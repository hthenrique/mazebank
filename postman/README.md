# Postman — MazeBank

## Importar

1. Postman → **Import**
2. Selecione:
   - `MazeBank.postman_collection.json`
   - `MazeBank.local.postman_environment.json` (opcional)
3. Selecione o environment **MazeBank Local** (canto superior direito)

`baseUrl` padrão: `http://localhost:8080/mazebank`

## Ordem de teste

1. **Health Check**
2. **Create User** — gera email único no pre-request
3. **Authenticate User** — `username` = email
4. **Fetch User** — grava `userUid` automaticamente
5. **Deposit User**
6. **Fetch User (After Deposit)** — saldo deve ser `150.5` (100 + 50.5)

## Headers importantes

| Request | Header | Valor |
|---------|--------|--------|
| Fetch User | `user-key` | email do usuário |
| Deposit User | `user-uid` | ObjectId (`uid` do Fetch) |

## Observação

No authenticate, o campo JSON `username` deve ser o **email**: a API busca por `_userEmail`.
