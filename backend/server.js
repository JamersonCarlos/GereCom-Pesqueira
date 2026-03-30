require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan'); // import do middleware de logs
const pool = require('./db/connection');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

// Log formatado com Método HTTP, URL, Status Code e tempo de resposta
app.use(morgan(':method :url :status :res[content-length] - :response-time ms'));

// Interceptor extra para logar os Bodys das requisições importantes na depuração
app.use((req, res, next) => {
  if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
    console.log(`[BODY RECEIVED] na rota ${req.url}:`, JSON.stringify(req.body, null, 2));
  }
  next();
});

// Rotas
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/plannings', require('./routes/plannings'));
app.use('/api/services', require('./routes/services'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/shifts', require('./routes/shifts'));

// Health check
app.get('/api/health', (_, res) => res.json({ status: 'ok' }));

// Seed usuários padrão ao iniciar
async function seedUsers() {
  const defaultUsers = [
    { username: 'gerente', name: 'Gerente Geral', role: 'GENERAL_MANAGER' },
    { username: 'gestor', name: 'Gestor de Equipe', role: 'GESTOR' },
    { username: 'secretaria', name: 'Secretaria Demo', role: 'SECRETARY' },
    { username: 'funcionario', name: 'Colaborador Demo', role: 'EMPLOYEE' },
    { username: 'admin', name: 'Gerente (Antigo)', role: 'MANAGER' }
  ];

  for (const u of defaultUsers) {
    const [rows] = await pool.query(
      "SELECT id FROM users WHERE username = ?", [u.username]
    );
    if (!rows.length) {
      const hash = await bcrypt.hash('123', 10);
      await pool.query(
        `INSERT INTO users (id, username, password, name, role, status)
         VALUES (?, ?, ?, ?, ?, 'ACTIVE')`,
        [uuidv4(), u.username, hash, u.name, u.role]
      );
      console.log(`✅ Usuário padrão criado: ${u.username} / 123 (${u.role})`);
    }
  }
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`🚀 GereCom API rodando na porta ${PORT}`);
  try {
    await seedUsers();
  } catch (err) {
    console.error('Erro ao fazer seed de usuários:', err.message);
  }
});
