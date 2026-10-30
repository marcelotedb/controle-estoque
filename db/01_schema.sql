-- Schema do controle de estoque (Task 1).

CREATE TABLE unidades (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo  text NOT NULL UNIQUE CHECK (codigo IN ('XAM', 'SAGA', 'ARA')),
  nome    text NOT NULL
);

INSERT INTO unidades (codigo, nome) VALUES
  ('XAM',  'Xambioá (sede)'),
  ('SAGA', 'São Geraldo do Araguaia'),
  ('ARA',  'Araguanã');

CREATE TABLE locais_uso (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome       text NOT NULL UNIQUE,
  tipo       text NOT NULL CHECK (tipo IN ('exclusivo', 'compartilhado')),
  unidade_id uuid REFERENCES unidades (id),
  CHECK ((tipo = 'exclusivo') = (unidade_id IS NOT NULL))
);

CREATE TABLE itens (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo            text NOT NULL UNIQUE,
  nome              text NOT NULL,
  categoria         text NOT NULL CHECK (categoria IN ('Peças', 'Revenda', 'Insumos')),
  localizacao       text,
  quantidade_minima integer NOT NULL DEFAULT 0 CHECK (quantidade_minima >= 0),
  criado_em         timestamptz NOT NULL DEFAULT now()
);

CREATE SEQUENCE seq_ret;
CREATE SEQUENCE seq_dev;

CREATE TABLE movimentacoes (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero             text UNIQUE,
  tipo               text NOT NULL CHECK (tipo IN ('retirada', 'devolucao', 'ajuste')),
  item_id            uuid NOT NULL REFERENCES itens (id),
  quantidade         integer NOT NULL CHECK (quantidade > 0),
  unidade_id         uuid REFERENCES unidades (id),
  local_uso_id       uuid REFERENCES locais_uso (id),
  responsavel        text NOT NULL,
  data_hora          timestamptz NOT NULL DEFAULT now(),
  retirada_origem_id uuid REFERENCES movimentacoes (id),
  condicao           text CHECK (condicao IN ('reuso', 'defeito')),
  status             text NOT NULL DEFAULT 'concluida' CHECK (status IN ('concluida', 'pendente')),
  -- sinal só importa para 'ajuste': quantidade é sempre a magnitude (> 0), e o
  -- sinal diz se o ajuste soma (correção para cima) ou subtrai (correção para
  -- baixo, ex.: contagem física menor que o sistema). Para retirada/devolução
  -- o sinal fica no valor padrão e não é usado pela view de saldos.
  sinal              integer NOT NULL DEFAULT 1 CHECK (sinal IN (1, -1)),
  CHECK (tipo <> 'retirada' OR (unidade_id IS NOT NULL AND local_uso_id IS NOT NULL)),
  CHECK (tipo <> 'devolucao' OR (retirada_origem_id IS NOT NULL AND condicao IS NOT NULL))
);
