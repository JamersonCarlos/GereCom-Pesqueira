-- ========================================
-- GereCom Pesqueira — Schema MySQL
-- ========================================

CREATE DATABASE IF NOT EXISTS gerecom_pesqueira
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE gerecom_pesqueira;

-- Usuários
CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(36)  PRIMARY KEY,
  username      VARCHAR(100) UNIQUE NOT NULL,
  password      VARCHAR(255) NOT NULL,
  name          VARCHAR(200) NOT NULL,
  email         VARCHAR(200),
  phone         VARCHAR(20),
  role          ENUM('SECRETARY','MANAGER','EMPLOYEE','GESTOR','GENERAL_MANAGER') NOT NULL DEFAULT 'EMPLOYEE',
  status        ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
  `function`    VARCHAR(200),
  manager_id    VARCHAR(36),
  reset_token           VARCHAR(64),
  reset_token_expires   DATETIME,
  must_change_password  TINYINT(1) NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT NOW(),
  FOREIGN KEY (manager_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Planejamentos
CREATE TABLE IF NOT EXISTS plannings (
  id                  VARCHAR(36)  PRIMARY KEY,
  manager_id          VARCHAR(36)  NOT NULL,
  secretary_id        VARCHAR(36)  NOT NULL,
  service_type        VARCHAR(200) NOT NULL,
  department          VARCHAR(200) NOT NULL,
  status              ENUM('PENDING','APPROVED','REJECTED','IN_PROGRESS','COMPLETED','CANCELLED','RESCHEDULED','WAITING_APPROVAL') NOT NULL DEFAULT 'PENDING',
  urgency_level       ENUM('LOW','MEDIUM','HIGH','URGENT') NOT NULL DEFAULT 'MEDIUM',
  period              ENUM('WEEKLY','MONTHLY','ANNUAL','UNPLANNED') NOT NULL DEFAULT 'UNPLANNED',
  description         TEXT,
  scheduled_date      VARCHAR(20) NOT NULL,
  scheduled_time      VARCHAR(10),
  location_desc       VARCHAR(500),
  location_lat        DECIMAL(10,8),
  location_lng        DECIMAL(11,8),
  rejection_reason    TEXT,
  estimated_hours     INT,
  team_size           INT DEFAULT 1,
  notes               TEXT,
  observations        TEXT,
  created_at          DATETIME NOT NULL DEFAULT NOW(),
  updated_at          DATETIME NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  FOREIGN KEY (manager_id)   REFERENCES users(id),
  FOREIGN KEY (secretary_id) REFERENCES users(id)
);

-- Serviços
CREATE TABLE IF NOT EXISTS services (
  id                      VARCHAR(36)  PRIMARY KEY,
  planning_id             VARCHAR(36),
  manager_id              VARCHAR(36)  NOT NULL,
  created_by_id           VARCHAR(36)  NOT NULL,
  service_type_snapshot   VARCHAR(200) NOT NULL,
  department_snapshot     VARCHAR(200) NOT NULL,
  scheduled_date          VARCHAR(20)  NOT NULL,
  scheduled_time          VARCHAR(10),
  status                  ENUM('PENDING','APPROVED','REJECTED','IN_PROGRESS','COMPLETED','CANCELLED','RESCHEDULED','WAITING_APPROVAL') NOT NULL DEFAULT 'IN_PROGRESS',
  description             TEXT,
  location_desc           VARCHAR(500),
  secretary_id_snapshot   VARCHAR(36),
  observations            TEXT,
  completion_notes        TEXT,
  manager_confirmed       TINYINT(1) NOT NULL DEFAULT 0,
  reason                  TEXT,
  completed_by_id         VARCHAR(36),
  created_at              DATETIME NOT NULL DEFAULT NOW(),
  updated_at              DATETIME NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  FOREIGN KEY (planning_id)   REFERENCES plannings(id) ON DELETE SET NULL,
  FOREIGN KEY (manager_id)    REFERENCES users(id),
  FOREIGN KEY (created_by_id) REFERENCES users(id)
);

-- Equipe do serviço
CREATE TABLE IF NOT EXISTS service_team (
  service_id  VARCHAR(36) NOT NULL,
  user_id     VARCHAR(36) NOT NULL,
  PRIMARY KEY (service_id, user_id),
  FOREIGN KEY (service_id) REFERENCES services(id)  ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id)     ON DELETE CASCADE
);

-- Notificações
CREATE TABLE IF NOT EXISTS notifications (
  id          VARCHAR(36)  PRIMARY KEY,
  user_id     VARCHAR(36)  NOT NULL,
  manager_id  VARCHAR(36),
  title       VARCHAR(200) NOT NULL,
  message     TEXT         NOT NULL,
  type        ENUM('service','schedule','general') NOT NULL DEFAULT 'general',
  related_id  VARCHAR(36),
  is_read     TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL DEFAULT NOW(),
  FOREIGN KEY (user_id)    REFERENCES users(id),
  FOREIGN KEY (manager_id) REFERENCES users(id)
);

-- Escalas
CREATE TABLE IF NOT EXISTS shifts (
  id          VARCHAR(36)  PRIMARY KEY,
  manager_id  VARCHAR(36)  NOT NULL,
  date        VARCHAR(20)  NOT NULL,
  start_time  VARCHAR(10),
  end_time    VARCHAR(10),
  observations TEXT,
  created_at  DATETIME NOT NULL DEFAULT NOW(),
  FOREIGN KEY (manager_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Funcionários da escala
CREATE TABLE IF NOT EXISTS shift_employees (
  shift_id  VARCHAR(36) NOT NULL,
  user_id   VARCHAR(36) NOT NULL,
  PRIMARY KEY (shift_id, user_id),
  FOREIGN KEY (shift_id) REFERENCES shifts(id)  ON DELETE CASCADE,
  FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE
);
