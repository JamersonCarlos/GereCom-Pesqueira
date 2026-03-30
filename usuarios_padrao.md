# GereCom Pesqueira - Documentação de Usuários Padrão

Este documento detalha os perfis de acesso criados automaticamente (seed) no banco de dados para testes, homologação e demonstração do aplicativo GereCom Pesqueira.

Todos os usuários abaixo possuem a **senha padrão de acesso**: `123`

---

## Tabela de Contas Padrão

| Nível de Acesso (Role) | Nome de Usuário (Login) | Nome do Perfil | Responsabilidades Principais |
| :--- | :--- | :--- | :--- |
| **Gerente Geral** (`GENERAL_MANAGER`) | `gerente` | Gerente Geral | Visão global do sistema; controle completo, análise de relatórios executivos e supervisão abrangente. |
| **Gestor de Equipe** (`GESTOR`) | `gestor` | Gestor de Equipe | Responsável operacional por aprovar/rejeitar os planejamentos da secretaria, criar serviços, designar equipe (escalas) e gerenciar status no dia a dia. |
| **Gerente/Antigo** (`MANAGER`) | `admin` | Gerente (Antigo) | Perfil legado originalmente cadastrado como admin. Funções idênticas as do Gestor e Gerente na visualização do Mobile. |
| **Secretaria** (`SECRETARY`) | `secretaria` | Secretaria Demo | Representante administrativa das diversas secretarias do município; cadastra demandas de serviços, define níveis de urgência e localidade, acompanhando status da solicitação. |
| **Colaborador** (`EMPLOYEE`) | `funcionario` | Colaborador Demo | Profissional de campo; fotógrafos, designers, assistentes de comunicação. Seu papel principal é visualizar onde/quando atuará (Escalas) e reportar o andamento da sua tarefa em campo até sua conclusão. |


## Fluxo Lógico Entre os Usuários

Abaixo segue um fluxo didático de como testar a jornada em sua integralidade:

1. **Início (Secretaria)**: 
   * Faça login com `secretaria` / `123`. 
   * Acesse a tela de Planejamentos e inicie uma Nova Solicitação de serviço preenchendo todos os dados.
   
2. **Avaliação (Gestor/Gerente)**:
   * Faça login com `gestor` / `123`. 
   * Visualize a demanda criada pela secretaria na tela "Planejamentos Pendentes".
   * APROVE o planejamento. Ao fazê-lo, a demanda transforma-se num **Serviço**.
   * Adicione também a composição de trabalho na aba **"Escalas"**, atribuindo o colaborador.funcio
   
3. **Execução em Campo (Colaborador)**:
   * Faça login com `funcionario` / `123`. 
   * Olhe as notificações e sua lista de serviços. 
   * Assuma seu trabalho informando quando iniciar e, ao finalizar, modifique o status para "Concluído (Aguardando Aprovação)". 
   
4. **Finalização (Gestor)**:
   * Volte ao `gestor` ou `gerente`, analise o preenchimento do funcionário e marque o serviço confirmando-o como COMPLETO permanentemente.
