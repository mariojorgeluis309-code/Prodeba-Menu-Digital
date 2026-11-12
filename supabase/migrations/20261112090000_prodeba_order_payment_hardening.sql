-- Prodeba: alinhamento entre pedidos, pagamentos e onboarding multi-restaurante.
-- Mantém o rastreio público sem expor dados pessoais do cliente.

CREATE OR REPLACE FUNCTION public.rastrear_pedido(p_codigo text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_p public.pedidos;
  v_itens jsonb;
  v_payment_status text;
  v_payment_total numeric := 0;
  v_payment_count integer := 0;
  v_confirmed_count integer := 0;
BEGIN
  IF p_codigo IS NULL OR btrim(p_codigo) = '' OR length(p_codigo) > 50 THEN
    RETURN NULL;
  END IF;

  SELECT p.* INTO v_p
  FROM public.pedidos p
  WHERE upper(p.codigo) = upper(btrim(p_codigo))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'nome', i.nome_produto,
        'quantidade', i.quantidade,
        'preco', i.preco,
        'subtotal', i.subtotal
      ) ORDER BY i.created_at
    ),
    '[]'::jsonb
  )
  INTO v_itens
  FROM public.itens_pedido i
  WHERE i.pedido_id = v_p.id;

  IF jsonb_array_length(v_itens) = 0 AND jsonb_typeof(v_p.itens) = 'array' THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'nome', coalesce(e ->> 'nome', e ->> 'nome_produto', e ->> 'name'),
          'quantidade', e -> 'quantidade',
          'preco', e -> 'preco',
          'subtotal', e -> 'subtotal'
        )
      ),
      '[]'::jsonb
    )
    INTO v_itens
    FROM jsonb_array_elements(v_p.itens) e;
  END IF;

  SELECT
    count(*),
    coalesce(sum(pg.valor), 0),
    count(*) FILTER (WHERE lower(coalesce(pg.status, '')) = 'pago')
  INTO v_payment_count, v_payment_total, v_confirmed_count
  FROM public.pagamentos pg
  WHERE pg.pedido_id = v_p.id;

  IF v_payment_count = 0 THEN
    v_payment_status := 'pendente';
  ELSIF abs(v_payment_total - v_p.total) > 0.01 THEN
    v_payment_status := 'em_verificacao';
  ELSIF v_confirmed_count = v_payment_count THEN
    -- Estado de apresentação mantido por compatibilidade com o frontend.
    v_payment_status := 'confirmado';
  ELSE
    v_payment_status := 'pendente';
  END IF;

  RETURN jsonb_build_object(
    'codigo', v_p.codigo,
    'status', v_p.status,
    'total', v_p.total,
    'status_pagamento', v_payment_status,
    'created_at', v_p.created_at,
    'metodo_pagamento', v_p.metodo_pagamento,
    'itens', v_itens
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rastrear_pedido(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rastrear_pedido(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.confirmar_pagamento_pedido(p_pedido_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_p public.pedidos;
  v_count integer := 0;
  v_total numeric := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT p.*
  INTO v_p
  FROM public.pedidos p
  JOIN public.restaurantes r ON r.id = p.restaurante_id
  WHERE p.id = p_pedido_id
    AND r.owner_id = v_uid
  FOR UPDATE OF p;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PEDIDO_NAO_ENCONTRADO_OU_SEM_PERMISSAO';
  END IF;

  IF v_p.status = 'cancelado' THEN
    RAISE EXCEPTION 'PEDIDO_CANCELADO';
  END IF;

  SELECT count(*), coalesce(sum(pg.valor), 0)
  INTO v_count, v_total
  FROM public.pagamentos pg
  WHERE pg.pedido_id = v_p.id
    AND pg.restaurante_id = v_p.restaurante_id;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'PAGAMENTO_NAO_REGISTADO';
  END IF;

  IF abs(v_total - v_p.total) > 0.01 THEN
    RAISE EXCEPTION 'TOTAL_PAGAMENTOS_NAO_CORRESPONDE_AO_PEDIDO';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.pagamentos pg
    WHERE pg.pedido_id = v_p.id
      AND pg.status NOT IN ('pago', 'pendente', 'processando')
  ) THEN
    RAISE EXCEPTION 'PAGAMENTO_COM_ESTADO_INVALIDO';
  END IF;

  UPDATE public.pagamentos
  SET status = 'pago'
  WHERE pedido_id = v_p.id
    AND restaurante_id = v_p.restaurante_id
    AND status IN ('pendente', 'processando');

  UPDATE public.pedidos
  SET status = 'pago'
  WHERE id = v_p.id;

  RETURN jsonb_build_object(
    'pedido_id', v_p.id,
    'codigo', v_p.codigo,
    'status', 'pago',
    'valor_confirmado', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirmar_pagamento_pedido(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirmar_pagamento_pedido(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.criar_meu_estabelecimento(
  p_nome text,
  p_tipo text DEFAULT 'restaurante',
  p_telefone text DEFAULT NULL,
  p_endereco text DEFAULT NULL,
  p_descricao text DEFAULT NULL
)
RETURNS public.restaurantes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_rest public.restaurantes;
  v_tipo text := lower(trim(coalesce(p_tipo, 'restaurante')));
  v_nome text := nullif(trim(coalesce(p_nome, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF v_nome IS NULL OR length(v_nome) > 120 THEN
    RAISE EXCEPTION 'NOME_OBRIGATORIO_OU_INVALIDO';
  END IF;

  IF v_tipo NOT IN ('restaurante', 'hotel', 'fast-food', 'bar', 'takeaway', 'cafe', 'outro') THEN
    RAISE EXCEPTION 'TIPO_INVALIDO';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.restaurantes r
    WHERE r.owner_id = v_uid
      AND r.ativo = true
  ) THEN
    RAISE EXCEPTION 'ESTABELECIMENTO_JA_EXISTE';
  END IF;

  INSERT INTO public.restaurantes (
    nome, tipo_estabelecimento, telefone, endereco, descricao, owner_id, ativo
  )
  VALUES (
    v_nome,
    v_tipo,
    nullif(trim(coalesce(p_telefone, '')), ''),
    nullif(trim(coalesce(p_endereco, '')), ''),
    nullif(trim(coalesce(p_descricao, '')), ''),
    v_uid,
    true
  )
  RETURNING * INTO v_rest;

  INSERT INTO public.perfis (id, nome, role, restaurante_id)
  VALUES (
    v_uid,
    nullif(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), ''),
    'restaurante',
    v_rest.id
  )
  ON CONFLICT (id) DO UPDATE
  SET restaurante_id = EXCLUDED.restaurante_id,
      role = 'restaurante';

  RETURN v_rest;
END;
$$;

REVOKE ALL ON FUNCTION public.criar_meu_estabelecimento(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_meu_estabelecimento(text, text, text, text, text) TO authenticated;
