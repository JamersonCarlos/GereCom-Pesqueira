const router = require('express').Router();
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/connection');
const auth = require('../middleware/auth');

function _map(p) {
  return {
    id: p.id,
    managerId: p.manager_id,
    secretaryId: p.secretary_id,
    serviceType: p.service_type,
    department: p.department,
    status: p.status,
    urgency: p.urgency_level,
    period: p.period,
    description: p.description || null,
    date: p.scheduled_date,
    time: p.scheduled_time || null,
    location: p.location_desc
      ? {
          address: p.location_desc,
          lat: p.location_lat,
          lng: p.location_lng,
        }
      : null,
    rejectionReason: p.rejection_reason || null,
    estimatedHours: p.estimated_hours || null,
    teamSize: p.team_size,
    notes: p.notes || null,
    observations: p.observations || null,
    createdAt: p.created_at,
    updatedAt: p.updated_at,
  };
}

// GET /api/plannings?managerId=xxx
router.get('/', auth, async (req, res) => {
  const { managerId } = req.query;
  try {
    const [rows] = managerId
      ? await pool.query(
          'SELECT * FROM plannings WHERE manager_id = ? ORDER BY created_at DESC',
          [managerId]
        )
      : await pool.query('SELECT * FROM plannings ORDER BY created_at DESC');
    res.json(rows.map(_map));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/plannings
router.post('/', auth, async (req, res) => {
  const b = req.body;
  const id = b.id || uuidv4();
  try {
    await pool.query(
      `INSERT INTO plannings
         (id, manager_id, secretary_id, service_type, department, status,
          urgency_level, period, description, scheduled_date, scheduled_time,
          location_desc, location_lat, location_lng, estimated_hours,
          team_size, notes, observations)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        id,
        b.managerId,
        b.secretaryId,
        b.serviceType,
        b.department,
        b.status || 'PENDING',
        b.urgency || 'MEDIUM',
        b.period || 'UNPLANNED',
        b.description || null,
        b.date,
        b.time || null,
        b.location?.address || null,
        b.location?.lat || null,
        b.location?.lng || null,
        b.estimatedHours || null,
        b.teamSize || 1,
        b.notes || null,
        b.observations || null,
      ]
    );
    const [rows] = await pool.query('SELECT * FROM plannings WHERE id = ?', [
      id,
    ]);
    res.status(201).json(_map(rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/plannings/:id/status
router.patch('/:id/status', auth, async (req, res) => {
  const { status, rejectionReason } = req.body;
  try {
    await pool.query(
      'UPDATE plannings SET status = ?, rejection_reason = ? WHERE id = ?',
      [status, rejectionReason || null, req.params.id]
    );
    const [rows] = await pool.query('SELECT * FROM plannings WHERE id = ?', [
      req.params.id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: 'Planejamento não encontrado.' });
    res.json(_map(rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/plannings/:id
router.put('/:id', auth, async (req, res) => {
  const b = req.body;
  try {
    await pool.query(
      `UPDATE plannings SET service_type=?, department=?, description=?,
       scheduled_date=?, scheduled_time=?, urgency_level=?, period=?, notes=?, observations=?
       WHERE id = ?`,
      [
        b.serviceType,
        b.department,
        b.description || null,
        b.date,
        b.time || null,
        b.urgency,
        b.period,
        b.notes || null,
        b.observations || null,
        req.params.id,
      ]
    );
    const [rows] = await pool.query('SELECT * FROM plannings WHERE id = ?', [
      req.params.id,
    ]);
    res.json(_map(rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/plannings/:id
router.delete('/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM plannings WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
