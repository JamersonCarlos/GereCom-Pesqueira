const nodemailer = require('nodemailer');
const path = require('path');

const LOGO_PATH = path.join(__dirname, '../assets/pesqueira-logo.png');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT || '587', 10),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

/**
 * Envolve o conteúdo no template institucional da Prefeitura de Pesqueira.
 * @param {string} bodyHtml - HTML do corpo principal
 * @returns {string}
 */
function emailTemplate(bodyHtml) {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GereCom Pesqueira</title>
</head>
<body style="margin:0;padding:0;background-color:#f0f2f5;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f2f5;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.10);">

          <!-- ── Cabeçalho ── -->
          <tr>
            <td align="center" style="background-color:#ffffff;padding:32px 40px 24px;">
              <img src="cid:pesqueira_logo" alt="Prefeitura de Pesqueira" width="110" style="display:block;margin:0 auto 16px;"/>
              <p style="margin:0;color:#1C3D7A;font-size:11px;font-weight:bold;letter-spacing:2.5px;text-transform:uppercase;">Sistema de Gestão de Colaboradores</p>
            </td>
          </tr>

          <!-- ── Faixa decorativa ── -->
          <tr>
            <td style="background:linear-gradient(90deg,#1C3D7A 0%,#2E5FAA 50%,#F5C200 100%);height:4px;font-size:0;line-height:0;">&nbsp;</td>
          </tr>

          <!-- ── Corpo ── -->
          <tr>
            <td style="padding:40px 40px 32px;color:#333333;font-size:15px;line-height:1.7;">
              ${bodyHtml}
            </td>
          </tr>

          <!-- ── Divisor ── -->
          <tr>
            <td style="height:1px;background-color:#e8e8e8;font-size:0;line-height:0;">&nbsp;</td>
          </tr>

          <!-- ── Rodapé ── -->
          <tr>
            <td style="background-color:#f8f9fb;padding:20px 40px;text-align:center;">
              <p style="margin:0 0 4px;font-size:12px;color:#555;font-weight:bold;">Prefeitura Municipal de Pesqueira — GereCom</p>
              <p style="margin:0;font-size:11px;color:#999;">Este é um e-mail automático gerado pelo sistema. Por favor, não responda.</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Envia um e-mail via SMTP configurado no .env.
 * O HTML é automaticamente embrulhado no template institucional.
 * @param {{ to: string, subject: string, html: string }} opts
 */
async function sendMail({ to, subject, html }) {
  await transporter.sendMail({
    from: `"GereCom Pesqueira" <${process.env.SMTP_USER}>`,
    to,
    subject,
    html: emailTemplate(html),
    attachments: [
      {
        filename: 'pesqueira-logo.png',
        path: LOGO_PATH,
        cid: 'pesqueira_logo',
      },
    ],
  });
}

module.exports = { sendMail };
