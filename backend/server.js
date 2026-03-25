require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db/connection');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

// Rotas
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/plannings', require('./routes/plannings'));
app.use('/api/services', require('./routes/services'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/shifts', require('./routes/shifts'));

// Health check
app.get('/api/health', (_, res) => res.json({ status: 'ok' }));

// Seed admin padrão ao iniciar
async function seedAdmin() {
  const [rows] = await pool.query(
    "SELECT id FROM users WHERE username = 'admin'"
  );
  if (!rows.length) {
    const hash = await bcrypt.hash('123', 10);
    await pool.query(
      `INSERT INTO users (id, username, password, name, role, status)
       VALUES (?, 'admin', ?, 'Gerente Demo', 'MANAGER', 'ACTIVE')`,
      [uuidv4(), hash]
    );
    console.log('✅ Admin padrão criado: admin / 123');
  }
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`🚀 GereCom API rodando na porta ${PORT}`);
  try {
    await seedAdmin();
  } catch (err) {
    console.error('Erro ao seed admin:', err.message);
  }
});
