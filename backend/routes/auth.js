const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/connection');
const auth = require('../middleware/auth');

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password)
    return res
      .status(400)
      .json({ error: 'username e password são obrigatórios.' });

  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE username = ?', [
      username,
    ]);
    if (!rows.length)
      return res.status(401).json({ error: 'Usuário não encontrado.' });

    const user = rows[0];
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(401).json({ error: 'Senha incorreta.' });
    if (user.status === 'INACTIVE')
      return res
        .status(403)
        .json({ error: 'Usuário inativo. Contate o administrador.' });

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    delete user.password;
    res.json({ token, user: _mapUser(user) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/register
router.post('/register', auth, async (req, res) => {
  const { username, password, name, role, managerId, function: fn } = req.body;
  if (!username || !password || !name)
    return res
      .status(400)
      .json({ error: 'username, password e name são obrigatórios.' });

  try {
    const [exists] = await pool.query(
      'SELECT id FROM users WHERE username = ?',
      [username]
    );
    if (exists.length)
      return res.status(409).json({ error: 'Nome de usuário já em uso.' });

    const hash = await bcrypt.hash(password, 10);
    const id = uuidv4();
    await pool.query(
      `INSERT INTO users (id, username, password, name, role, function, manager_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        username,
        hash,
        name,
        role || 'EMPLOYEE',
        fn || null,
        managerId || null,
      ]
    );

    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
    const user = rows[0];
    delete user.password;
    res.status(201).json(_mapUser(user));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/auth/profile
router.put('/profile', auth, async (req, res) => {
  const { name, email, phone } = req.body;
  const userId = req.user.id;
  try {
    await pool.query(
      'UPDATE users SET name = ?, email = ?, phone = ? WHERE id = ?',
      [name, email, phone, userId]
    );
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [
      userId,
    ]);
    const user = rows[0];
    delete user.password;
    res.json(_mapUser(user));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me
router.get('/me', auth, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [
      req.user.id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    const user = rows[0];
    delete user.password;
    res.json(_mapUser(user));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function _mapUser(u) {
  return {
    id: u.id,
    username: u.username,
    name: u.name,
    email: u.email || null,
    phone: u.phone || null,
    role: u.role,
    status: u.status,
    function: u.function || null,
    managerId: u.manager_id || null,
    createdAt: u.created_at,
  };
}

module.exports = router;
