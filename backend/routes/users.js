const router = require('express').Router();
const pool = require('../db/connection');
const auth = require('../middleware/auth');

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

// GET /api/users  — todos os usuários
router.get('/', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, username, name, email, phone, role, status, `function`, manager_id, created_at FROM users'
    );
    res.json(rows.map(_mapUser));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/users/team/:managerId  — membros da equipe
router.get('/team/:managerId', auth, async (req, res) => {
  const { managerId } = req.params;
  try {
    const [rows] = await pool.query(
      `SELECT id, username, name, email, phone, role, status, \`function\`, manager_id, created_at
       FROM users
       WHERE id = ?
          OR manager_id = ?
          OR manager_id IN (SELECT id FROM users WHERE manager_id = ?)`,
      [managerId, managerId, managerId]
    );
    res.json(rows.map(_mapUser));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/users/:id  — atualizar dados do usuário
router.put('/:id', auth, async (req, res) => {
  const { name, email, phone, function: fn } = req.body;
  try {
    await pool.query(
      'UPDATE users SET name = ?, email = ?, phone = ?, `function` = ? WHERE id = ?',
      [name, email || null, phone || null, fn || null, req.params.id]
    );
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [
      req.params.id,
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

// PATCH /api/users/:id/status  — ativar/inativar usuário
router.patch('/:id/status', auth, async (req, res) => {
  const { status } = req.body;
  if (!['ACTIVE', 'INACTIVE'].includes(status))
    return res.status(400).json({ error: 'Status inválido.' });
  try {
    await pool.query('UPDATE users SET status = ? WHERE id = ?', [
      status,
      req.params.id,
    ]);
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [
      req.params.id,
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

// DELETE /api/users/:id
router.delete('/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
