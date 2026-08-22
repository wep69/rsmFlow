# Design — `dsh-peak-indicator` (indicador de horário de pico no DSH)

- **Data:** 2026-08-15
- **Status:** Aprovado pelo usuário (design) — aguardando revisão da spec
- **Escopo:** plugin cliente único para o DeepSeek Harness Web (profile `web`)

## 1. Objetivo

Mostrar no rodapé do chat do DSH um chip que indica, em tempo real, se a
tarifação da API DeepSeek está em **horário de pico** ou **fora de pico** —
vermelho no pico, verde fora — com tooltip contendo as faixas convertidas para
o horário de Brasília e o tempo até a próxima troca.

**Fonte de verdade:** a faixa oficial de Beijing 09:00–12:00 e 14:00–18:00
(anúncio de 2026-08-17, preços pico/vale do DeepSeek V4).

## 2. Decisões de produto (confirmadas com o usuário)

| Decisão | Escolha |
|---|---|
| Conteúdo | Só o status (🔴 "Pico" / 🟢 "Fora de pico") |
| Localização | Composer dock (rodapé do chat, ao lado do chip de saldo) |
| Tooltip | Sim — faixas em Brasília + contagem até a próxima troca |
| Abordagem | Plugin independente (não tocar no balance-meter) |
| Idioma | Textos fixos em PT-BR |

## 3. Arquitetura

- **100% cliente** — sem host half, sem rede, sem serviços DSH além de `slots`.
- Pacote em `C:\Users\wep69\.dsh\plugins\dsh-peak-indicator`, instalado via
  `dsh plugin --profile web add -w link:<caminho>` (mesmo padrão do
  `dsh-steer-button`).
- Arquivos:
  - `package.json` — `dsh.client` (inject `@deepseek-ai/dsh-client-runtime`,
    `@deepseek-ai/dsh-client-ui-slots`, `@deepseek-ai/dsh-client-ui-conversation`;
    platform `web`) + `dsh.bundle.patch` apontando para `cordis.patch.yml`.
  - `cordis.patch.yml` — `- insert: - id: peak-indicator, name: dsh-peak-indicator`.
  - `lib/client.js` — escrito à mão no formato `window.__ModuleLoader__.load`
    (sem build step; mesmo formato do client compilado do balance-meter).
- Montagem: `ctx.inject(["slots", "conversation"])` e
  `ctx.slots.register({ name: "conversation.composer.dock", id: "peak-indicator", order: 130, ... })`
  — exatamente o padrão do balance-meter.

## 4. Componentes (funções puras)

| Função | Responsabilidade |
|---|---|
| `beijingHour(date)` | Hora de Beijing via `Intl.DateTimeFormat("en-US", { timeZone: "Asia/Shanghai", hour: "numeric", hour12: false })` |
| `isPeak(date)` | `h >= 9 && h < 12 \|\| h >= 14 && h < 18` (Beijing) |
| `nextTransition(date)` | Próximo instante UTC de fronteira entre as faixas (9/12/14/18 Beijing) |
| `peakWindowsBrasilia()` | As duas faixas convertidas para America/Sao_Paulo (UTC−3, fixo) |

- Chip: estado React local (`useState` + `useEffect`) atualizado por
  `setTimeout` agendado para a fronteira exata da próxima troca + um intervalo
  de segurança de 60 s.
- Tooltip (CSS puro, estilo do chip do balance-meter): "Pico: 22h–1h e
  3h–7h (Brasília)" + "termina em Xh Ym".
- Falha improvável do `Intl`: chip cinza com "—" (não quebra a página).

## 5. Fluxo de dados

```
relógio do navegador → beijingHour → isPeak → estado do chip (vermelho/verde)
                                     └→ nextTransition → setTimeout da próxima troca
```

Sem persistência, sem localStorage, sem chamadas de rede. YAGNI.

## 6. Tratamento de erros

| Caso | Comportamento |
|---|---|
| `Intl` indisponível/falha | chip cinza "—", sem exceção visível |
| Timeout do setTimeout desalinhado | intervalo de segurança de 60 s re-sincroniza |
| Slot não disponível (outro cliente) | plugin não monta o chip (no-op silencioso) |

## 7. Testes

Testes unitários das funções puras com timestamps fixos (vitest ou Node
`node:test`):

| Timestamp (UTC) | Beijing | Esperado |
|---|---|---|
| 2026-08-17T01:00Z | 09:00 | pico começa |
| 2026-08-17T03:00Z | 11:00 | pico ativo |
| 2026-08-17T04:00Z | 12:00 | fora de pico |
| 2026-08-17T06:00Z | 14:00 | pico começa |
| 2026-08-17T09:59Z | 17:59 | pico ativo |
| 2026-08-17T10:00Z | 18:00 | fora de pico |
| 2026-08-17T15:00Z | 23:00 | fora de pico |

Smoke manual: hard refresh no DSH → chip aparece ao lado do saldo e alterna
vermelho/verde conforme a hora local; tooltip mostra as faixas de Brasília.

## 8. Fora de escopo (YAGNI)

- Timeline de 24 h, alarmes, notificações
- Configuração de fuso/fronteiras customizadas
- i18n (textos PT-BR fixos)
- Host half, MCP, persistência de preferências

## 9. Critérios de aceite

1. Chip visível no composer dock de toda sessão web.
2. Vermelho durante 09–12/14–18 Beijing; verde fora.
3. Tooltip lista as faixas em Brasília (22h–1h, 3h–7h) e o tempo até a próxima troca.
4. Instalação por `dsh plugin add -w link:` sem erros; bundle registrado.
5. Testes unitários das fronteiras passando.

*Nota: o workspace atual não é um repositório git — o commit do spec foi
omitido por não haver repo onde fazê-lo sem efeitos colaterais.*
