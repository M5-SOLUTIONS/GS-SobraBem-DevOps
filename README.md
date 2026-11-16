# SobraBem API - Doação de comida que sobra

API REST para conectar quem tem comida sobrando a quem precisa, desenvolvida em Java com Spring Boot, Maven, JPA/Hibernate e Oracle Database. Padarias, feiras e mercados publicam o que sobrou no fim do dia, com quantidade e horário limite de retirada; ONGs e famílias reservam uma parte e retiram no local com um código.

---

# Desenvolvido por

- Guilherme Cintra RM562850
- Erick de Faria Gama RM561951
- Matheus Nascimento Corregio RM563765
- Pedro Fonseca de Almeida RM563466
- Daniel Fonseca de Almeida RM563045

---


# Descrição do projeto

Todo fim de dia, pães, frutas e refeições prontas que ainda estão boas para consumo vão para o lixo, porque doar dá trabalho: o comércio não sabe quem precisa, e quem precisa não sabe onde tem comida disponível. O SobraBem resolve essa parte da coordenação.

A solução tem duas partes integradas: a API principal, desenvolvida em Java com Spring, que guarda os dados, aplica as regras de negócio e controla o acesso; e um aplicativo móvel, por onde doadores e receptores usam a plataforma no dia a dia.

A API é o núcleo da solução. Ela cuida do cadastro de usuários, da publicação de doações com prazo de retirada, das reservas com desconto de saldo e da confirmação da retirada pelo código. Cada usuário enxerga apenas o que lhe diz respeito: um doador só edita as próprias doações, um receptor só vê o código das próprias reservas, e nenhum dos dois acessa as funções de administração.

---

# Objetivo

A aplicação reduz o desperdício de alimentos e facilita a doação, permitindo:

- Cadastro e autenticação de doadores e receptores
- Publicação de doações com quantidade, categoria e prazo de retirada
- Reserva de parte de uma doação, com saldo atualizado na hora
- Confirmação da retirada com um código de 6 caracteres
- Expiração automática das doações e reservas vencidas

A API foi desenvolvida em arquitetura REST, com persistência em banco de dados Oracle.

---

# Benefícios

**Menos comida no lixo.** O comércio publica a sobra em segundos e ela chega a quem precisa no mesmo dia, em vez de ser descartada.

**Nada de reserva além do disponível.** O saldo é descontado no banco de forma atômica: dois receptores disputando a última unidade nunca conseguem reservar juntos mais do que existe.

**Prazo respeitado.** A API recusa reservas depois do horário limite e expira sozinha as doações vencidas, sem depender de ninguém lembrar.

**Retirada sem confusão.** O receptor mostra o código no balcão e o doador confirma no app; a doação fica registrada.

**Histórico centralizado.** Doações, reservas e retiradas ficam registradas no banco, disponíveis para doador, receptor e administração a qualquer momento.

---

# Arquitetura da Solução

## Visão geral

A solução segue um modelo de **aplicação monolítica hospedada em PaaS com banco de dados externo**. Não há infraestrutura de servidor sob nossa responsabilidade: o Azure App Service cuida do runtime Java e o Oracle guarda os dados. O que gerenciamos é o *código* e a *configuração*.

![Arquitetura da solução SobraBem](./docs/architecture.png)

## Recursos utilizados

**Microsoft Azure**
- **Resource Group** — agrupa todos os recursos da solução
- **App Service Plan** — Linux, SKU F1 (free tier)
- **App Service (Web App)** — hospeda o `.jar` do Spring Boot, runtime Java 21

**Azure DevOps** (projeto privado)
- **Azure Boards** — tarefas do projeto, vinculadas a branches, commits e pull requests
- **Azure Repos** — repositório Git do código-fonte, com a branch `main` protegida
- **Azure Pipelines (Build / CI)** — compila com Maven, roda os testes automáticos e publica o pacote e os resultados dos testes
- **Azure Pipelines (Release)** — publica o pacote no App Service sempre que o CI gera um novo artefato

**Externos**
- **Oracle** — banco de dados da aplicação

> O banco **não** é provisionado pelo script de infraestrutura e **não** roda dentro do App Service. Ele já existe no Oracle da FIAP, e a aplicação se conecta a ele por JDBC, com credenciais injetadas como variáveis de ambiente. Destruir e recriar todo o ambiente Azure não afeta os dados.

## Estrutura do repositório

```text
/
├── azure-pipeline.yml        Pipeline de Build (CI)
├── scripts/
│   ├── cria-infra.sh         Provisionamento no Azure (Azure CLI)
│   └── script-bd.sql         DDL dos objetos do banco
├── docs/
│   └── architecture.png      Desenho macro da arquitetura
├── src/                      Código-fonte da API (Java 21, Spring Boot)
└── pom.xml                   Dependências e build Maven
```

O deploy no Azure publica o `.jar` direto no App Service, sem containers.

## Camadas da aplicação

Dentro do App Service, a aplicação segue arquitetura em camadas: requisição HTTP → Spring Security (filtro JWT) → Controllers (`/api/**`) → Services → Repositories (Spring Data JPA) → Hibernate → Oracle Database. À parte, o Flyway aplica as migrations no banco a cada inicialização.

- **Spring Security** valida o token JWT antes de qualquer controller ser alcançado e aplica os papéis `DOADOR`, `RECEPTOR` e `ADMIN`; as rotas de autenticação e o Swagger ficam fora dessa exigência.
- **Controllers** expõem os endpoints REST e traduzem HTTP em chamadas de serviço, sem regra de negócio.
- **Services** concentram as regras: prazo de retirada por categoria, desconto atômico do saldo, uma reserva ativa por receptor, código de retirada e cancelamentos.
- **Repositories** abstraem o acesso ao banco via Spring Data JPA.
- **Scheduler** roda a cada 5 minutos e marca como expiradas as doações e reservas com prazo vencido.
- **Flyway** roda na subida da aplicação e garante que o schema do Oracle esteja na versão esperada pelo código. O deploy do `.jar` e a evolução do banco acontecem juntos, sem passo manual. O histórico fica em `sb_flyway_schema_history`.

---

# Fluxos de Funcionamento

## 1. Fluxo de acesso

Seta ① do diagrama: o app mobile e o navegador (Swagger) acessam a aplicação pela URL pública do App Service, sempre via HTTPS. As rotas `/api/**` exigem o token JWT obtido no login, exceto cadastro e login.

## 2. Fluxo de deploy (CI/CD)

Seta ② do diagrama. É o fluxo que caracteriza a esteira de DevOps: da tarefa no Boards até a aplicação no ar, sem intervenção manual.

1. Uma **tarefa** é criada no **Azure Boards**.
2. O desenvolvedor cria uma **branch** a partir da `main`, altera o código e faz os **commits** vinculados à tarefa.
3. Abre um **pull request** para a `main`, também vinculado à tarefa. As políticas da branch exigem revisor e work item vinculado.
4. Depois da aprovação, o **merge na `main`** dispara a **pipeline de Build (CI)**, definida em `azure-pipeline.yml`: build Maven, **testes automáticos** e publicação do **pacote (`.jar`)** e dos **resultados dos testes**.
5. O novo artefato dispara a **pipeline de Release**, que publica o `.jar` no **App Service**.
6. O App Service reinicia a aplicação, o Flyway valida/aplica as migrations no Oracle, e a nova versão fica disponível na URL pública.
7. A tarefa no Boards mostra os links da branch, dos commits e do pull request.

## Políticas da branch `main`

| Política | Configuração |
|---|---|
| Revisor obrigatório | Pelo menos 1 aprovação; o autor pode aprovar a própria PR (simulação) |
| Vinculação de work item | Toda PR precisa estar ligada a uma tarefa do Boards |
| Revisor padrão | RM do integrante responsável, adicionado automaticamente em toda PR |

Com a `main` protegida, nenhum código entra sem PR, e o Build só roda depois do merge.

## 3. Fluxo de dados

Seta ③ do diagrama: a aplicação se conecta ao Oracle por JDBC. URL, usuário e senha do banco não estão no código; são lidos das variáveis de ambiente configuradas no App Service.

## Provisionamento inicial

Executado uma única vez, via `scripts/cria-infra.sh`:

1. Registra os providers do Azure utilizados na assinatura
2. Cria o Resource Group
3. Cria o App Service Plan (Linux, F1)
4. Cria o Web App com runtime Java 21
5. Configura as variáveis de ambiente da aplicação (banco, JWT e usuário ADMIN)
6. Reinicia o Web App para aplicar a configuração

A partir daí, cada merge na `main` publica uma nova versão pelas pipelines; o script não precisa ser executado de novo.

## Variáveis de ambiente

Configuradas em **App Service → Configuration → Application settings**. Nenhuma delas fica no repositório; o `.env.example` traz só os nomes.

| Variável | Para quê |
|---|---|
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | conexão JDBC com o Oracle da FIAP |
| `JWT_SECRET` | assinatura dos tokens (32 caracteres ou mais) |
| `ADMIN_EMAIL`, `ADMIN_SENHA` | usuário ADMIN criado na primeira subida |
| `SPRING_PROFILES_ACTIVE` | `fake`: a orientação de conservação usa a resposta simulada e a API não chama o Gemini |

## Variáveis nas pipelines

As pipelines também usam variáveis, e nenhuma senha fica escrita nos arquivos:

| Pipeline | Variável | Para quê |
|---|---|---|
| Build | `javaVersion`, `mavenGoals` | versão do Java e comando do Maven (`clean package`, com os testes) |
| Release | `WEBAPP_NAME`, `RESOURCE_GROUP` | Web App e Resource Group de destino |
| Release | `azureSubscription` | Service Connection que autoriza o deploy |

## Segurança e configuração

| Preocupação | Como é tratada |
|---|---|
| Credenciais do banco e segredo do JWT | Variáveis de ambiente no App Service, nunca no repositório |
| Tráfego externo | HTTPS fornecido pelo App Service |
| Acesso à API | Token JWT obrigatório nas rotas `/api/**`, com controle por papel |
| Senhas dos usuários | Guardadas com hash BCrypt |
| Credencial de deploy | Service Connection do Azure DevOps, que autoriza o Azure Pipelines a publicar no App Service |
| Alterações no código | Branch `main` protegida: só entra código por PR revisada e vinculada a uma tarefa |

---

# Como criar o Web App no Azure

O script de provisionamento está em **`scripts/cria-infra.sh`**.

## Pré-requisitos

- Azure CLI instalado e autenticado (`az login`)
- Permissão para criar recursos na assinatura do Azure
- Banco Oracle da FIAP já existente e acessível (o script **não** cria o banco)

## Passo a passo

**1. Entre na pasta do script**

```bash
cd scripts
```

**2. Dê permissão de execução e execute o script**

```bash
chmod +x cria-infra.sh
./cria-infra.sh
```

**3. Valide a aplicação**

```
https://<WEBAPP_NAME>.azurewebsites.net/swagger-ui.html
```

## Depois do primeiro deploy

- Todo merge de PR na branch `main` do Azure Repos dispara o Build (CI) e, em seguida, a Release.
- Para trocar qualquer credencial, altere em **App Service → Configuration → Application settings**; o Web App reinicia sozinho.
- Para destruir todo o ambiente: `az group delete --name <RESOURCE_GROUP_NAME>`. O banco no Oracle da FIAP permanece intacto.

---

# CRUD da API (JSON)

Todas as operações das 4 tabelas, com os bodies em JSON. A mesma lista está documentada no Swagger, em `https://<WEBAPP_NAME>.azurewebsites.net/swagger-ui.html`.

**Base:** `https://<WEBAPP_NAME>.azurewebsites.net`

Todas as rotas exigem o header `Authorization: Bearer <token>`, exceto cadastro e login. O token vem no campo `token` da resposta do login e vale por 2 horas. Os ids nas rotas (`/6`, `/3`, `/5`) são exemplos: use os ids devolvidos nas respostas de criação.

| Tabela | Create | Read | Update | Delete |
|---|---|---|---|---|
| `sb_t_usuario` | `POST /api/auth/registro` | `GET /api/usuarios/me` · `GET /api/usuarios/{id}` (ADMIN) | `PUT /api/usuarios/me` | `DELETE /api/usuarios/{id}` (ADMIN) |
| `sb_t_categoria` | `POST /api/categorias` (ADMIN) | `GET /api/categorias` · `GET /api/categorias/{id}` | `PUT /api/categorias/{id}` (ADMIN) | `DELETE /api/categorias/{id}` (ADMIN) |
| `sb_t_doacao` | `POST /api/doacoes` (DOADOR) | `GET /api/doacoes/{id}` · `GET /api/doacoes/minhas` | `PUT /api/doacoes/{id}` (DOADOR dono) | `DELETE /api/doacoes/{id}` (DOADOR dono ou ADMIN) |
| `sb_t_reserva` | `POST /api/reservas` (RECEPTOR) | `GET /api/reservas/minhas` · `GET /api/doacoes/{id}/reservas` | `PATCH /api/reservas/{id}/retirada` (DOADOR da doação) | `DELETE /api/reservas/{id}` (ADMIN) |

## Autenticação

`POST /api/auth/registro`, doador:

```json
{
  "nome": "Padaria Pão Quente",
  "email": "contato@paoquente.com.br",
  "senha": "Senha123",
  "telefone": "11987654321",
  "papel": "DOADOR",
  "endereco": "Avenida Paulista, 1000 - Bela Vista",
  "cidade": "São Paulo",
  "uf": "SP"
}
```

`POST /api/auth/registro`, receptor:

```json
{
  "nome": "ONG Mesa Solidária",
  "email": "contato@mesasolidaria.org.br",
  "senha": "Senha123",
  "telefone": "11912345678",
  "papel": "RECEPTOR",
  "endereco": null,
  "cidade": "São Paulo",
  "uf": "SP"
}
```

`POST /api/auth/login`:

```json
{
  "email": "contato@paoquente.com.br",
  "senha": "Senha123"
}
```

Para o ADMIN, o login usa o `ADMIN_EMAIL` e a `ADMIN_SENHA` configurados no App Service. O ADMIN não pode ser cadastrado pela API.

## Usuários

`PUT /api/usuarios/me` (doador; para receptor, use `"endereco": null`):

```json
{
  "nome": "Padaria Pão Quente Ltda",
  "telefone": "11987654321",
  "endereco": "Avenida Paulista, 1200 - Bela Vista",
  "cidade": "São Paulo",
  "uf": "SP"
}
```

`GET /api/usuarios/me` e `GET /api/usuarios/{id}` não têm body. `DELETE /api/usuarios/{id}` (ADMIN) também não, e só é aceito para usuário sem doações nem reservas; senão a API responde `409 REGISTRO_EM_USO`.

## Categorias (ADMIN)

`POST /api/categorias`:

```json
{
  "nome": "Congelados",
  "descricao": "Alimentos mantidos no freezer",
  "prazoMaxHoras": 8
}
```

`PUT /api/categorias/6`:

```json
{
  "nome": "Congelados e resfriados",
  "descricao": "Alimentos mantidos no freezer ou na geladeira",
  "prazoMaxHoras": 6
}
```

`GET /api/categorias/6` e `DELETE /api/categorias/6` não têm body. O `DELETE` só é aceito para categoria sem doações.

## Doações (DOADOR)

`POST /api/doacoes`:

```json
{
  "titulo": "Pão francês",
  "descricao": "Assados às 15h, cerca de 30 pães",
  "categoriaId": 1,
  "quantidadeTotal": 10,
  "unidade": "UNIDADE",
  "prazoRetirada": "2026-11-17T06:00:00-03:00",
  "orientacoesConservacao": "Manter em embalagem fechada, em local seco.",
  "geradaPorIa": false
}
```

`PUT /api/doacoes/3` (o body é o mesmo da criação):

```json
{
  "titulo": "Pão francês",
  "descricao": "Assados às 15h, cerca de 40 pães",
  "categoriaId": 1,
  "quantidadeTotal": 15,
  "unidade": "UNIDADE",
  "prazoRetirada": "2026-11-17T06:00:00-03:00",
  "orientacoesConservacao": "Manter em embalagem fechada, em local seco e longe do sol.",
  "geradaPorIa": true
}
```

Sobre o `prazoRetirada`:

- Ele precisa ficar entre 30 minutos e o prazo máximo da categoria, contados a partir do envio. Pães e bolos aceita até 12 h. Ajuste a data e a hora para o momento do teste.
- Na edição, `quantidadeTotal` não pode ficar menor que o que já foi reservado.
- Os outros valores de `unidade` são `KG` e `PACOTE`.

`GET /api/doacoes/3` e `DELETE /api/doacoes/3` não têm body. O `DELETE` só é aceito para doação sem reservas.

## Reservas

`POST /api/reservas` (RECEPTOR):

```json
{
  "doacaoId": 3,
  "quantidade": 2
}
```

`PATCH /api/reservas/5/retirada` (DOADOR da doação, com o código que o receptor recebeu):

```json
{
  "codigoRetirada": "K7P2QX"
}
```

`GET /api/reservas/minhas` (RECEPTOR) e `DELETE /api/reservas/5` (ADMIN) não têm body.

## Ordem para executar o CRUD completo

As tabelas têm chaves estrangeiras, então a criação vai das tabelas pai para as filhas, e a exclusão faz o caminho inverso:

1. **Create:** ADMIN cria a categoria → cadastro do doador e do receptor → doador cria a doação → receptor cria a reserva.
2. **Read:** consulta de cada registro pelas rotas `GET`.
3. **Update:** categoria (ADMIN) → `PUT /api/usuarios/me` → doação → retirada da reserva.
4. **Delete:** reserva (ADMIN) → doação → categoria (ADMIN) → doador e receptor (ADMIN).

## Conferindo no banco

Depois de cada operação, a persistência é conferida direto no Oracle:

```sql
SELECT * FROM sb_t_categoria WHERE id_categoria = 6;
SELECT * FROM sb_t_usuario   WHERE email IN ('contato@paoquente.com.br', 'contato@mesasolidaria.org.br');
SELECT * FROM sb_t_doacao    WHERE id_doacao = 3;
SELECT * FROM sb_t_reserva   WHERE id_reserva = 5;
```

Depois do `DELETE`, a mesma consulta não devolve nenhuma linha.