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
       FROM users WHERE manager_id = ? OR id = ?`,
      [managerId, managerId]
    );
    res.json(rows.map(_mapUser));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
