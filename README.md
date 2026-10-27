# Agenor 2.0

Reconstrução do Agenor, a plataforma de coleta de documentos fiscais na Receita. Cada coleta roda num Job próprio, criado pelo Launcher, e o Document Collector é o único dono do status e da retentativa.

```
Agenor → Document Collector → fila → Launcher → Job do worker (um por tipo)
```

Esta pasta reúne o projeto para o trabalho local. O repositório dela guarda só a documentação; cada serviço é um repositório próprio, no padrão de repositórios separados do cliente.

| Pasta | Repositório | O que é |
|---|---|---|
| `agenor-document-collector/` | próprio | DC v2: orquestrador, no schema `agenor_v2`. Parte do DC atual (ver `ORIGEM.md`) |
| `agenor-launcher/` | próprio | Consome a fila e cria um Kubernetes Job por tentativa |
| `agenor-workers/` | próprio | `core/` (base comum) e `workers/` (um por tipo) |
| `agenor-common/` | próprio | Contratos (evento da fila, modelos da API) e interface de fila, instalado por tag Git |
| `docs/` | este | Plano (`PLANO_AGENOR_2_0.md`), contexto e decisões, diagnóstico, documentos do cliente |
| `docs/arquitetura/` | este | ADRs e `infra.md` |
| `referencia/` | nenhum | Snapshots do scraper e do download service, só para consulta ao portar os coletores |
