const router = require('express').Router();
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/connection');
const auth = require('../middleware/auth');

function _map(n) {
  return {
    id: n.id,
    userId: n.user_id,
    managerId: n.manager_id || null,
    title: n.title,
    message: n.message,
    type: n.type,
    relatedId: n.related_id || null,
    read: !!n.is_read,
    createdAt: n.created_at,
  };
}

// GET /api/notifications?userId=xxx
router.get('/', auth, async (req, res) => {
  const { userId } = req.query;
  try {
    const [rows] = userId
      ? await pool.query(
          'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC',
          [userId]
        )
      : await pool.query(
          'SELECT * FROM notifications ORDER BY created_at DESC'
        );
    res.json(rows.map(_map));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/notifications
router.post('/', auth, async (req, res) => {
  const b = req.body;
  const id = b.id || uuidv4();
  try {
    await pool.query(
      `INSERT INTO notifications (id, user_id, manager_id, title, message, type, related_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        b.userId,
        b.managerId || null,
        b.title,
        b.message,
        b.type || 'general',
        b.relatedId || null,
      ]
    );
    const [rows] = await pool.query(
      'SELECT * FROM notifications WHERE id = ?',
      [id]
    );
    res.status(201).json(_map(rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/notifications/:id/read
router.patch('/:id/read', auth, async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read = 1 WHERE id = ?', [
      req.params.id,
    ]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/notifications/read-all?userId=xxx
router.patch('/read-all', auth, async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId é obrigatório.' });
  try {
    await pool.query('UPDATE notifications SET is_read = 1 WHERE user_id = ?', [
      userId,
    ]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
