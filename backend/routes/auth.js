const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const pool = require('../db/connection');
const auth = require('../middleware/auth');
const { sendMail } = require('../utils/mailer');

/** Gera senha aleatória de 10 caracteres alfanuméricos */
function _generatePassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  return Array.from(
    { length: 10 },
    () => chars[Math.floor(Math.random() * chars.length)]
  ).join('');
}

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

// POST /api/auth/register (Gerentes/Gestores/Secretários criam subordinados)
router.post('/register', auth, async (req, res) => {
  const { username, email, name, role, managerId, functionRole } = req.body;

  if (!username || !email || !name)
    return res
      .status(400)
      .json({ error: 'username, email e name são obrigatórios.' });

  try {
    const [exists] = await pool.query(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    // Usuário legado (criado antes do sistema de e-mail): tem username mas sem e-mail.
    // Nesse caso, completamos o cadastro em vez de rejeitar.
    if (exists.length) {
      const legacy = exists[0];
      if (legacy.email) {
        return res.status(409).json({ error: 'Nome de usuário já em uso.' });
      }

      // Verifica se o e-mail já pertence a outro usuário
      const [emailExists] = await pool.query(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [email, legacy.id]
      );
      if (emailExists.length)
        return res.status(409).json({ error: 'E-mail já cadastrado.' });

      const plainPassword = _generatePassword();
      const hash = await bcrypt.hash(plainPassword, 10);

      await pool.query(
        'UPDATE users SET email = ?, password = ?, must_change_password = 1 WHERE id = ?',
        [email, hash, legacy.id]
      );

      try {
        await sendMail({
          to: email,
          subject: 'GereCom Pesqueira — Seu acesso foi configurado',
          html: `
            <p style="font-size:16px;font-weight:bold;color:#1C3D7A;margin:0 0 16px;">Olá, ${legacy.name}!</p>
            <p style="margin:0 0 12px;">Seu acesso ao <strong>GereCom Pesqueira</strong> foi configurado com sucesso. Utilize as credenciais abaixo para entrar no sistema:</p>
            <table cellpadding="0" cellspacing="0" style="background:#f0f4ff;border-left:4px solid #1C3D7A;border-radius:6px;padding:16px 20px;margin:20px 0;width:100%;">
              <tr><td style="padding:4px 0;"><span style="color:#555;font-size:13px;">USUÁRIO</span></td></tr>
              <tr><td style="padding:0 0 12px;"><strong style="font-size:16px;color:#1C3D7A;">${legacy.username}</strong></td></tr>
              <tr><td style="padding:4px 0;"><span style="color:#555;font-size:13px;">SENHA TEMPORÁRIA</span></td></tr>
              <tr><td><strong style="font-size:22px;letter-spacing:3px;color:#1C3D7A;font-family:Courier,monospace;">${plainPassword}</strong></td></tr>
            </table>
            <p style="margin:0 0 8px;">Por segurança, recomendamos que você altere sua senha após o primeiro acesso.</p>
            <p style="margin:0;color:#888;font-size:13px;">Se você não esperava este e-mail, entre em contato com o administrador do sistema.</p>
          `,
        });
      } catch (mailErr) {
        console.error('[EMAIL] Falha ao enviar senha:', mailErr.message);
      }

      const [updated] = await pool.query('SELECT * FROM users WHERE id = ?', [
        legacy.id,
      ]);
      const user = updated[0];
      delete user.password;
      return res.status(200).json(_mapUser(user));
    }

    const [emailExists] = await pool.query(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );
    if (emailExists.length)
      return res.status(409).json({ error: 'E-mail já cadastrado.' });

    const plainPassword = _generatePassword();
    const hash = await bcrypt.hash(plainPassword, 10);
    const id = uuidv4();

    await pool.query(
      `INSERT INTO users (id, username, password, name, email, role, \`function\`, manager_id, must_change_password)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        id,
        username,
        hash,
        name,
        email,
        role || 'EMPLOYEE',
        functionRole || null,
        managerId || null,
      ]
    );

    // Envia a senha gerada por e-mail
    try {
      await sendMail({
        to: email,
        subject: 'Bem-vindo ao GereCom Pesqueira — Sua senha de acesso',
        html: `
          <p style="font-size:16px;font-weight:bold;color:#1C3D7A;margin:0 0 16px;">Bem-vindo, ${name}!</p>
          <p style="margin:0 0 12px;">Sua conta no <strong>GereCom Pesqueira</strong> foi criada com sucesso. Utilize as credenciais abaixo para acessar o sistema:</p>
          <table cellpadding="0" cellspacing="0" style="background:#f0f4ff;border-left:4px solid #1C3D7A;border-radius:6px;padding:16px 20px;margin:20px 0;width:100%;">
            <tr><td style="padding:4px 0;"><span style="color:#555;font-size:13px;">USUÁRIO</span></td></tr>
            <tr><td style="padding:0 0 12px;"><strong style="font-size:16px;color:#1C3D7A;">${username}</strong></td></tr>
            <tr><td style="padding:4px 0;"><span style="color:#555;font-size:13px;">SENHA TEMPORÁRIA</span></td></tr>
            <tr><td><strong style="font-size:22px;letter-spacing:3px;color:#1C3D7A;font-family:Courier,monospace;">${plainPassword}</strong></td></tr>
          </table>
          <p style="margin:0 0 8px;">Por segurança, recomendamos que você altere sua senha após o primeiro acesso.</p>
          <p style="margin:0;color:#888;font-size:13px;">Se você não esperava este e-mail, entre em contato com o administrador do sistema.</p>
        `,
      });
    } catch (mailErr) {
      console.error('[EMAIL] Falha ao enviar senha:', mailErr.message);
      // Não bloqueia o cadastro se o e-mail falhar
    }

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

// POST /api/auth/forgot-password
router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'E-mail é obrigatório.' });

  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [
      email,
    ]);
    // Responde sempre com 200 para não revelar se o e-mail existe
    if (!rows.length)
      return res.json({
        message: 'Se o e-mail estiver cadastrado, você receberá o código.',
      });

    const user = rows[0];
    // Código de 6 dígitos, expira em 30 minutos
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 30 * 60 * 1000);

    await pool.query(
      'UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?',
      [code, expires, user.id]
    );

    try {
      await sendMail({
        to: email,
        subject: 'GereCom Pesqueira — Código de recuperação de senha',
        html: `
          <p style="font-size:16px;font-weight:bold;color:#1C3D7A;margin:0 0 16px;">Olá, ${user.name}!</p>
          <p style="margin:0 0 20px;">Recebemos uma solicitação para redefinir a senha da sua conta. Use o código abaixo para continuar:</p>
          <table cellpadding="0" cellspacing="0" width="100%" style="margin:0 0 20px;">
            <tr>
              <td align="center" style="background:#1C3D7A;border-radius:8px;padding:20px 40px;">
                <p style="margin:0 0 6px;color:#F5C200;font-size:11px;letter-spacing:2px;text-transform:uppercase;font-weight:bold;">Código de Verificação</p>
                <p style="margin:0;font-size:38px;letter-spacing:12px;font-weight:bold;color:#ffffff;font-family:Courier,monospace;">${code}</p>
              </td>
            </tr>
          </table>
          <p style="margin:0 0 8px;">Este código é válido por <strong>30 minutos</strong>.</p>
          <p style="margin:0;color:#888;font-size:13px;">Se você não solicitou a recuperação de senha, ignore este e-mail. Sua senha permanece a mesma.</p>
        `,
      });
    } catch (mailErr) {
      console.error('[EMAIL] Falha ao enviar código:', mailErr.message);
      return res
        .status(500)
        .json({ error: 'Falha ao enviar e-mail. Tente novamente.' });
    }

    res.json({
      message: 'Se o e-mail estiver cadastrado, você receberá o código.',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/reset-password
router.post('/reset-password', async (req, res) => {
  const { email, code, newPassword } = req.body;
  if (!email || !code || !newPassword)
    return res
      .status(400)
      .json({ error: 'email, code e newPassword são obrigatórios.' });

  if (newPassword.length < 6)
    return res
      .status(400)
      .json({ error: 'A senha deve ter pelo menos 6 caracteres.' });

  try {
    const [rows] = await pool.query(
      'SELECT * FROM users WHERE email = ? AND reset_token = ?',
      [email, code]
    );

    if (!rows.length)
      return res.status(400).json({ error: 'Código inválido.' });

    const user = rows[0];
    if (
      !user.reset_token_expires ||
      new Date(user.reset_token_expires) < new Date()
    )
      return res
        .status(400)
        .json({ error: 'Código expirado. Solicite um novo.' });

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query(
      'UPDATE users SET password = ?, reset_token = NULL, reset_token_expires = NULL WHERE id = ?',
      [hash, user.id]
    );

    res.json({ message: 'Senha redefinida com sucesso.' });
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
    mustChangePassword:
      u.must_change_password === 1 || u.must_change_password === true,
    createdAt: u.created_at,
  };
}

// POST /api/auth/change-password
router.post('/change-password', auth, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword)
    return res
      .status(400)
      .json({ error: 'currentPassword e newPassword são obrigatórios.' });
  if (newPassword.length < 6)
    return res
      .status(400)
      .json({ error: 'A nova senha deve ter pelo menos 6 caracteres.' });

  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [
      req.user.id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: 'Usuário não encontrado.' });

    const user = rows[0];
    const valid = await bcrypt.compare(currentPassword, user.password);
    if (!valid)
      return res.status(401).json({ error: 'Senha atual incorreta.' });

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query(
      'UPDATE users SET password = ?, must_change_password = 0 WHERE id = ?',
      [hash, user.id]
    );

    const [updated] = await pool.query('SELECT * FROM users WHERE id = ?', [
      user.id,
    ]);
    const updatedUser = updated[0];
    delete updatedUser.password;
    res.json(_mapUser(updatedUser));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
