# Prodeba — Menu Digital

Plataforma de menu digital e gestão de restaurantes, com frontend estático e Supabase.

## Acesso

- **Menu público:** https://prodeba-menu-digital.onrender.com/
- **Painel do restaurante:** https://prodeba-menu-digital.onrender.com/?admin=1

O painel administrativo fica oculto na experiência pública normal. Abra o endereço com \`?admin=1\` para entrar ou criar uma conta.

## Primeiro acesso

1. Abra o endereço do painel.
2. Escolha **Criar conta de restaurante**.
3. Registe o email e uma palavra-passe com pelo menos 8 caracteres.
4. Se o Supabase pedir confirmação, confirme o email e volte ao painel para iniciar sessão.
5. Preencha os dados do estabelecimento.
6. Abra **Produtos** para adicionar nome, preço, descrição e imagem (URL ou ficheiro JPG/PNG/WebP até 2 MB).
7. Abra **Pagamentos** para configurar os métodos e contas que pertencem ao estabelecimento.
8. Abra **QR / Mesas** para criar QR geral ou QR individual por mesa.

Cada conta de restaurante está associada ao seu próprio estabelecimento. As operações de gestão usam as políticas RLS do Supabase e verificam a propriedade no servidor.

## Pedidos e pagamentos

- Os pedidos são criados pela função transacional \`criar_pedido_transacional\`.
- O servidor valida os produtos, preços, quantidades, mesa, valor total e token de idempotência.
- O acompanhamento público usa o código do pedido e a função \`rastrear_pedido\`.
- A confirmação no painel atualiza os registos da tabela \`pagamentos\` e o estado do pedido na mesma transação.
- M-Pesa, e-Mola, mKesh e transferência bancária são registados por referência e confirmados manualmente pelo responsável do restaurante.

**Importante:** não existe ainda integração automática com APIs de M-Pesa/e-Mola nem gateway Visa/Mastercard. A interface não deve apresentar estes meios como pagamentos automaticamente confirmados.

## Desenvolvimento e validação

Validação local com Node.js 20 ou superior:

\`\`\`bash
node scripts/validate-prodeba.mjs
\`\`\`

O GitHub Actions executa a validação em pushes nas branches \`main\` e \`debug/**\`, e em pull requests para \`main\`.

As alterações de banco de dados estão versionadas em \`supabase/migrations/\`.
