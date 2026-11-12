# Auditoria e correções Prodeba — novembro de 2026

## Alterações

- Checkout alterado de INSERT direto em \`pedidos\` para RPC transacional \`criar_pedido_transacional\`.
- Acompanhamento público corrigido para consultar \`rastrear_pedido(p_codigo)\`, usando a coluna real \`pedidos.codigo\`.
- Resolução de QR corrigida para usar \`resolver_qr(p_token)\`; a página pública já não depende de SELECT direto em \`qr_codes\`.
- Contexto da mesa vinculado ao restaurante do QR para impedir que uma mesa antiga seja reutilizada ao encomendar noutro estabelecimento.
- Confirmação de pagamentos implementada pela RPC \`confirmar_pagamento_pedido\`, com verificação de propriedade e correspondência entre pagamentos e total do pedido.
- Financeiro passa a somar apenas linhas de \`pagamentos\` com estado \`pago\`, sem inferir recebimentos a partir do estado de preparação/entrega.
- Onboarding passa pela RPC \`criar_meu_estabelecimento\` e cria/atualiza o perfil do utilizador.
- Adicionada gestão de métodos de pagamento por restaurante.
- Adicionado carregamento de imagens para o bucket público \`produtos\`, limitado a 2 MB e JPG/PNG/WebP.
- Adicionada criação de QR geral, além dos QR por mesa.
- Botão administrativo oculto na navegação pública normal; entrada pelo parâmetro \`?admin=1\`.
- QA atualizado para testar as RPCs públicas sem consultar tabelas privadas.
- Adicionado validador de sintaxe JavaScript e workflow GitHub Actions.

## Segurança

- As políticas RLS existentes continuam a restringir produtos, pedidos, pagamentos, despesas, métodos e QR à conta proprietária.
- O acesso público ao menu e à resolução de QR continua limitado a dados públicos/ativos.
- A RPC de confirmação de pagamento exige sessão autenticada e propriedade do restaurante.
- Não adicionar chaves \`service_role\` ao frontend.

## Limitações que permanecem explícitas

- M-Pesa/e-Mola/mKesh e transferência são fluxos de referência e confirmação manual, não integração automática com as operadoras.
- Visa/Mastercard não são oferecidos como método ativo até existir um gateway real.
- O envio de emails de confirmação/recuperação depende da configuração Auth/SMTP e das URLs autorizadas no Supabase.
- A validação automatizada verifica sintaxe e presença das funções essenciais; testes de ponta a ponta com conta real, email e pagamento devem ser feitos após o deploy.
