# OpenKore Neon Manager (local)

Painel web local para gerenciar múltiplas instâncias OpenKore com foco em **XKore 0**:

- criar e clonar instâncias;
- iniciar/parar/reiniciar processo do bot;
- iniciar/parar/reiniciar Poseidon por instância;
- visualizar logs em memória de cada processo.

## Executar

```bash
cd tools/openkore-manager
python3 server.py --host 127.0.0.1 --port 8787
```

Acesse: `http://127.0.0.1:8787`

## Notas

- O servidor persiste metadados em `instances.json`.
- Logs em arquivo ficam em `logs/<instance>-bot.log` e `logs/<instance>-poseidon.log`.
- Comandos são executados com `shell=True` no diretório de trabalho da instância.
- Esta é uma base inicial para evoluir autenticação, perfis por servidor, templates de controle e telemetria avançada.
