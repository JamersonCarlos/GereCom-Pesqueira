const router = require('express').Router();
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/connection');
const auth = require('../middleware/auth');

async function _mapShift(conn, s) {
  const [emps] = await conn.query(
    'SELECT user_id FROM shift_employees WHERE shift_id = ?',
    [s.id]
  );
  return {
    id: s.id,
    managerId: s.manager_id,
    date: s.date,
    startTime: s.start_time || null,
    endTime: s.end_time || null,
    observations: s.observations || null,
    employeeIds: emps.map((e) => e.user_id),
    createdAt: s.created_at,
  };
}

// GET /api/shifts?managerId=xxx
router.get('/', auth, async (req, res) => {
  const { managerId } = req.query;
  try {
    const [rows] = managerId
      ? await pool.query(
          'SELECT * FROM shifts WHERE manager_id = ? ORDER BY date ASC',
          [managerId]
        )
      : await pool.query('SELECT * FROM shifts ORDER BY date ASC');
    const shifts = await Promise.all(rows.map((s) => _mapShift(pool, s)));
    res.json(shifts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/shifts
router.post('/', auth, async (req, res) => {
  const b = req.body;
  const id = b.id || uuidv4();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query(
      `INSERT INTO shifts (id, manager_id, date, start_time, end_time, observations)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        id,
        b.managerId,
        b.date,
        b.startTime || null,
        b.endTime || null,
        b.observations || null,
      ]
    );
    if (b.employeeIds?.length) {
      const values = b.employeeIds.map((uid) => [id, uid]);
      await conn.query(
        'INSERT INTO shift_employees (shift_id, user_id) VALUES ?',
        [values]
      );
    }
    await conn.commit();
    const [rows] = await conn.query('SELECT * FROM shifts WHERE id = ?', [id]);
    res.status(201).json(await _mapShift(conn, rows[0]));
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// PUT /api/shifts/:id
router.put('/:id', auth, async (req, res) => {
  const b = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query(
      'UPDATE shifts SET date=?, start_time=?, end_time=?, observations=? WHERE id=?',
      [
        b.date,
        b.startTime || null,
        b.endTime || null,
        b.observations || null,
        req.params.id,
      ]
    );
    await conn.query('DELETE FROM shift_employees WHERE shift_id = ?', [
      req.params.id,
    ]);
    if (b.employeeIds?.length) {
      const values = b.employeeIds.map((uid) => [req.params.id, uid]);
      await conn.query(
        'INSERT INTO shift_employees (shift_id, user_id) VALUES ?',
        [values]
      );
    }
    await conn.commit();
    const [rows] = await conn.query('SELECT * FROM shifts WHERE id = ?', [
      req.params.id,
    ]);
    res.json(await _mapShift(conn, rows[0]));
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// DELETE /api/shifts/:id
router.delete('/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM shifts WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
