const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateContactPayload(req, res, next) {
  const { name, email, message, website } = req.body || {};

  if (!name || !email || !message) {
    return res.status(400).json({ error: 'Name, email, and message are required.' });
  }

  const trimmedName = String(name).trim();
  const trimmedEmail = String(email).trim();
  const trimmedMessage = String(message).trim();
  const trimmedWebsite = website ? String(website).trim() : '';

  if (!trimmedName || !trimmedEmail || !trimmedMessage) {
    return res.status(400).json({ error: 'Name, email, and message are required.' });
  }

  if (trimmedName.length > 120 || trimmedEmail.length > 254 || trimmedWebsite.length > 200) {
    return res.status(400).json({ error: 'One or more fields exceed the allowed length.' });
  }

  if (!EMAIL_RE.test(trimmedEmail)) {
    return res.status(400).json({ error: 'Please provide a valid email address.' });
  }

  if (trimmedMessage.length > 2000) {
    return res.status(400).json({ error: 'Message is too long. Please keep it under 2000 characters.' });
  }

  req.contact = {
    name: trimmedName,
    email: trimmedEmail,
    website: trimmedWebsite,
    message: trimmedMessage,
  };

  return next();
}

router.post('/', validateContactPayload, async (req, res) => {
  try {
    const { name, email, website, message } = req.contact;
    const ticket = {
      subject: `Website contact: ${name}`,
      message,
      userEmail: email,
      contactName: name,
      website,
      source: 'website',
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const created = await admin.firestore().collection('support_tickets').add(ticket);
    return res.status(201).json({
      success: true,
      id: created.id,
      message: 'Your message has been received. The church team will follow up with you.',
    });
  } catch (error) {
    console.error('Contact form submission could not be saved:', error);
    return res.status(500).json({ error: 'We could not send your message. Please try again later.' });
  }
});

module.exports = { router };
