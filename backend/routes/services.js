const router = require('express').Router();
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/connection');
const auth = require('../middleware/auth');

async function _mapService(conn, s) {
  const [team] = await conn.query(
    'SELECT user_id FROM service_team WHERE service_id = ?',
    [s.id]
  );
  return {
    id: s.id,
    planningId: s.planning_id || null,
    managerId: s.manager_id,
    createdById: s.created_by_id,
    serviceTypeSnapshot: s.service_type_snapshot,
    departmentSnapshot: s.department_snapshot,
    dateSnapshot: s.scheduled_date,
    timeSnapshot: s.scheduled_time || null,
    secretaryIdSnapshot: s.secretary_id_snapshot || null,
    locationSnapshot: s.location_desc ? { address: s.location_desc } : null,
    descriptionSnapshot: s.description || null,
    observationsSnapshot: s.observations || null,
    notes: s.completion_notes || null,
    managerConfirmed: !!s.manager_confirmed,
    reason: s.reason || null,
    completedBy: s.completed_by_id || null,
    status: s.status,
    teamIds: team.map((t) => t.user_id),
    createdAt: s.created_at,
    updatedAt: s.updated_at,
  };
}

// GET /api/services?managerId=xxx  OR  ?userId=xxx (for employees)
router.get('/', auth, async (req, res) => {
  const { managerId, userId } = req.query;
  try {
    let rows;
    if (userId) {
      // Returns services where this user is a team member
      [rows] = await pool.query(
        'SELECT s.* FROM services s JOIN service_team st ON s.id = st.service_id WHERE st.user_id = ? ORDER BY s.created_at DESC',
        [userId]
      );
    } else if (managerId) {
      [rows] = await pool.query(
        'SELECT * FROM services WHERE manager_id = ? ORDER BY created_at DESC',
        [managerId]
      );
    } else {
      [rows] = await pool.query(
        'SELECT * FROM services ORDER BY created_at DESC'
      );
    }
    const services = await Promise.all(rows.map((s) => _mapService(pool, s)));
    res.json(services);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/services
router.post('/', auth, async (req, res) => {
  const b = req.body;
  const id = b.id || uuidv4();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query(
      `INSERT INTO services
         (id, planning_id, manager_id, created_by_id, service_type_snapshot, department_snapshot,
          scheduled_date, scheduled_time, status, description, location_desc,
          secretary_id_snapshot, observations)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        id,
        b.planningId || null,
        b.managerId,
        b.createdById || b.managerId,
        b.serviceTypeSnapshot,
        b.departmentSnapshot,
        b.dateSnapshot,
        b.timeSnapshot || null,
        b.status || 'IN_PROGRESS',
        b.descriptionSnapshot || null,
        b.locationSnapshot?.address || null,
        b.secretaryIdSnapshot || null,
        b.observationsSnapshot || null,
      ]
    );
    if (b.teamIds?.length) {
      const values = b.teamIds.map((uid) => [id, uid]);
      await conn.query(
        'INSERT INTO service_team (service_id, user_id) VALUES ?',
        [values]
      );
    }
    await conn.commit();
    const [rows] = await conn.query('SELECT * FROM services WHERE id = ?', [
      id,
    ]);
    const service = await _mapService(conn, rows[0]);
    res.status(201).json(service);
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// PATCH /api/services/:id/status
router.patch('/:id/status', auth, async (req, res) => {
  const { status, notes, managerConfirmed, reason, completedBy } = req.body;
  try {
    await pool.query(
      `UPDATE services SET status = ?, completion_notes = ?,
       manager_confirmed = ?, reason = ?, completed_by_id = ? WHERE id = ?`,
      [
        status,
        notes ?? null,
        managerConfirmed ? 1 : 0,
        reason ?? null,
        completedBy ?? null,
        req.params.id,
      ]
    );
    const [rows] = await pool.query('SELECT * FROM services WHERE id = ?', [
      req.params.id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    res.json(await _mapService(pool, rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
