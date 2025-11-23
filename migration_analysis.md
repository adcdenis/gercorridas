# Análise de Migração: Angular para Flutter

Este documento resume a estrutura, telas, regras de negócio e funcionalidades do projeto Angular atual (`dstv-angular`) para auxiliar na migração para Flutter.

## Visão Geral
- **Tecnologia Atual:** Angular + PrimeNG
- **Backend:** Firebase (Authentication & Firestore)
- **Autenticação:** Email e Senha via Firebase Auth
- **Banco de Dados:** NoSQL (Firestore)

## Estrutura de Navegação (Telas)

### 1. Login (`/auth/login`)
- **Funcionalidade:** Autenticação de usuários.
- **Regras:**
  - Acesso restrito a usuários não autenticados.
  - Redireciona para `/cliente` ou `/dashboard` após sucesso.
  - Persistência de sessão local.

### 2. Dashboard (`/dashboard`)
- **Funcionalidade:** Visão geral do sistema.
- **Elementos:**
  - **Cards de Status:** Contagem de clientes Ativos, Vencidos e Vencendo em 3 dias.
  - **Gráfico:** Exibe dados estatísticos (atualmente com dados mockados no código, mas preparado para integração).
- **Lógica:**
  - Carrega todos os clientes e calcula os status localmente baseado na `dataVencimento`.

### 3. Gerenciar Clientes (`/cliente`)
- **Funcionalidade:** CRUD completo de clientes.
- **Listagem:**
  - Tabela com colunas: Vencimento, Nome, Alerta (WhatsApp), Plano, Servidor, Ações.
  - Paginação e ordenação.
- **Filtros:**
  - **Todos:** Exibe todos os clientes.
  - **Ativos:** `dataVencimento` >= data atual.
  - **Vencidos:** `dataVencimento` < data atual.
  - **3 Dias:** Vencimento entre hoje e hoje + 3 dias.
- **Ações:**
  - **Novo:** Abre modal de cadastro.
  - **Editar:** Abre modal com dados preenchidos.
  - **Excluir:** Remove cliente (confirmação via modal).
  - **Clonar:** Cria cópia do cliente adicionando " - 2" ao nome.
  - **WhatsApp:** Gera link para abrir conversa no WhatsApp com mensagem de cobrança personalizada (inclui nome, plano, valor, vencimento e dados de pagamento).
  - **Exportar:** Gera arquivo Excel (`.xlsx`) com a lista atual.
- **Formulário:**
  - Campos: Nome (obrigatório), Usuário, Email, Telefone (com máscara), Data Vencimento, Servidor (Select), Plano (Select), Observação.

### 4. Gerenciar Servidores (`/servidor`)
- **Funcionalidade:** CRUD simples de servidores.
- **Listagem:** Tabela com ID e Nome.
- **Ações:** Novo, Editar, Excluir.
- **Formulário:** Campo Nome (obrigatório).

### 5. Gerenciar Planos (`/plano`)
- **Funcionalidade:** CRUD simples de planos.
- **Listagem:** Tabela com ID, Nome e Valor.
- **Ações:** Novo, Editar, Excluir.
- **Formulário:** Campos Nome (obrigatório) e Valor.

## Modelos de Dados (Interfaces)

### Cliente (`ClienteI`)
- `id`: string (gerado pelo Firebase)
- `nome`: string
- `usuario`: string
- `email`: string
- `telefone`: string
- `dataVencimento`: Timestamp/Date
- `observacao`: string
- `servidor`: Objeto `ServidorI` (armazenado denormalizado ou referência)
- `plano`: Objeto `PlanoI` (armazenado denormalizado ou referência)

### Servidor (`ServidorI`)
- `id`: string
- `nome`: string

### Plano (`PlanoI`)
- `id`: string
- `nome`: string
- `valor`: number/string

## Regras de Negócio & Lógica

1.  **Cálculo de Vencimento:**
    - O status do cliente (Ativo/Vencido) não é salvo no banco, é calculado em tempo de execução comparando `dataVencimento` com a data atual (zerando as horas).

2.  **Mensagem de WhatsApp:**
    - A mensagem é montada dinamicamente no frontend (`cliente.component.ts`).
    - **Variáveis:**
        - `telefone`: Telefone do cliente.
        - `nomePlano`: Nome do plano vinculado.
        - `valorPlano`: Valor do plano vinculado.
        - `usuario`: Usuário do cliente (opcional).
        - `dataFormatada`: Data de vencimento formatada (dd/MM/yyyy).
        - `diaTardeNoite`: Saudação baseada na hora atual (Bom dia/tarde/noite).
    - **Estrutura da Mensagem:**
        ```text
        Olá, {diaTardeNoite}
        *Segue seu vencimento IPTV*
        *Vencimento:* _{dataFormatada}_

        *PLANO CONTRATADO*
        ⭕ _Plano:_ *{nomePlano}*
        ⭕ _Valor:_ *R$ {valorPlano}*
        [⭕ _Conta:_ *{usuario}*] (Se existir)

        *FORMAS DE PAGAMENTOS*
        ✅ Pic Pay : @canutobr
        ✅ Banco do Brasil: ag 3020-1 cc 45746-9
        ✅ Pix: canutopixbb@gmail.com

        - Duração da lista 30 dias, acesso de um ponto, não permite conexões simultâneas.
        - Assim que efetuar o pagamento, enviar o comprovante e vou efetuar a contratação/renovação o mais rápido possível.
        -*Aguardamos seu contato para renovação!*
        ```
    - **Recomendação:** Mover dados bancários e textos fixos para uma configuração remota (Remote Config ou Firestore) para evitar hardcoding no app Flutter.

3.  **Clonagem:**
    - Ao clonar, o ID é limpo para criar um novo registro e o nome recebe sufixo.

4.  **Relacionamentos:**
    - Clientes possuem vínculo com Servidor e Plano. No Angular, parece que o objeto inteiro é salvo junto com o cliente ou carregado via seleção. Na migração, considerar se manterá denormalizado ou usará apenas IDs.

## Considerações para Migração Flutter

- **Gerenciamento de Estado:** O app Angular usa estado local nos componentes e Observables dos serviços. No Flutter, considerar `Provider`, `Riverpod` ou `Bloc`.
- **UI/UX:** O projeto usa PrimeNG. No Flutter, utilizar Material Design (padrão) ou Cupertino, adaptando os componentes de Tabela e Dialogs.
- **Firebase:** Utilizar `firebase_auth` e `cloud_firestore`.
- **Datas:** Atenção à conversão de `Timestamp` do Firestore para `DateTime` do Dart.
- **Máscaras:** Utilizar `mask_text_input_formatter` ou similar para o campo de telefone.
- **Exportação:** Utilizar bibliotecas como `excel` ou `csv` para gerar relatórios.
