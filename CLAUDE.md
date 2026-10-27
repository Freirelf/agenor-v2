# Agenor 2.0

- Plano e decisões: `../agenor/PLANO_AGENOR_2_0.md` (fonte de trabalho) e `../agenor/CONTEXTO_E_DECISOES.md`. As decisões técnicas viram ADRs em `docs/arquitetura/`.
- Cada pasta de serviço é um repositório Git próprio; esta pasta só versiona a documentação. Commits vão no repositório do serviço alterado.
- Local primeiro: tudo é desenvolvido e validado localmente (fila e armazenamento locais); os ambientes são a última etapa.
- O v2 escreve só no schema `agenor_v2`; nunca altera as tabelas do `public` (DC atual e AGuiar).
- `referencia/` é só leitura: o código portado entra no `agenor-workers` com testes.
- Nenhuma credencial no código ou nos values: tudo vem de Secret ou variável de ambiente.
- Python 3.12, `uv`, `pydantic-settings`, `ruff`, `pytest`.
