const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Enable CORS so your mobile app can access this backend from the local Wi-Fi
app.use(cors());
app.use(express.json());

// In-Memory Database
const users = [
  {
    id: 'user_demo_id',
    name: 'Ayesha Khan',
    email: 'ayesha@example.com',
    password: 'password123',
    phone: '+92 310 1234567',
    healthId: 'PK-HC-9F2A-7T',
    dob: '14 Mar 1958',
    gender: 'Female',
    bloodGroup: 'B+',
  }
];

// Seed patient record data (only available for the demo user)
const visits = [
  {
    id: 'v1',
    dx: 'Hypertension review',
    doctor: 'Dr. Imran Yousuf',
    specialty: 'Cardiology',
    hospital: 'Shifa International Hospital',
    dateLabel: '18 Jun 2026',
    time: '09:30',
    symptoms: 'Occasional headaches, mild dizziness in mornings. BP 148/94 on arrival.',
    diagnosis: 'Essential hypertension (I10)',
    diagnosisNote: 'Well-controlled on current regimen. Continue monitoring.',
    meds: [
      { name: 'Amlodipine', strength: '5 mg', freq: 'Once daily', dur: '30 days' },
      { name: 'Metformin', strength: '500 mg', freq: 'Twice daily', dur: 'Ongoing' },
      { name: 'Aspirin', strength: '75 mg', freq: 'Once daily', dur: '30 days' },
    ],
    followUp: '24 Jun 2026',
    advice: 'Reduce salt intake, 30-min daily walk.',
  },
  {
    id: 'v2',
    dx: 'Diabetes follow-up',
    doctor: 'Dr. Sana Tariq',
    specialty: 'Endocrinology',
    hospital: 'Aga Khan University Hospital',
    dateLabel: '02 May 2026',
    time: '11:15',
    symptoms: 'Fasting sugar trending high last week. No acute complaints.',
    diagnosis: 'Type 2 diabetes mellitus (E11)',
    diagnosisNote: 'HbA1c improving. Maintain diet and metformin.',
    meds: [
      { name: 'Metformin', strength: '500 mg', freq: 'Twice daily', dur: 'Ongoing' },
      { name: 'Glimepiride', strength: '1 mg', freq: 'Once daily', dur: '30 days' },
    ],
    followUp: '02 Aug 2026',
    advice: 'Low-carb diet, monitor sugar twice daily.',
  },
  {
    id: 'v3',
    dx: 'Chest pain — cleared',
    doctor: 'Dr. Imran Yousuf',
    specialty: 'Cardiology',
    hospital: 'Shifa International Hospital',
    dateLabel: '21 Mar 2026',
    time: '16:40',
    symptoms: 'Transient chest tightness on exertion. ECG normal.',
    diagnosis: 'Non-cardiac chest pain (R07.9)',
    diagnosisNote: 'Cardiac causes ruled out. Likely musculoskeletal.',
    meds: [{ name: 'Pantoprazole', strength: '40 mg', freq: 'Once daily', dur: '14 days' }],
    followUp: 'As needed',
    advice: 'Return if pain recurs at rest.',
  },
  {
    id: 'v4',
    dx: 'Seasonal influenza',
    doctor: 'Dr. Bilal Aziz',
    specialty: 'General Medicine',
    hospital: 'CMH Lahore',
    dateLabel: '09 Feb 2026',
    time: '10:05',
    symptoms: 'Fever, body aches and dry cough for 3 days.',
    diagnosis: 'Influenza, unspecified (J11)',
    diagnosisNote: 'Symptomatic management. Rest and hydration.',
    meds: [
      { name: 'Paracetamol', strength: '500 mg', freq: 'As needed', dur: '5 days' },
      { name: 'Cetirizine', strength: '10 mg', freq: 'Once at night', dur: '5 days' },
    ],
    followUp: 'If not improving in 5 days',
    advice: 'Plenty of fluids and rest.',
  },
  {
    id: 'v5',
    dx: 'Eye check-up',
    doctor: 'Dr. Aasim Rehman',
    specialty: 'Ophthalmology',
    hospital: 'Shifa International Hospital',
    dateLabel: '15 Jan 2026',
    time: '14:00',
    symptoms: 'Blurry vision in left eye when reading.',
    diagnosis: 'Presbyopia (H52.4)',
    diagnosisNote: 'Prescribed reading glasses. Follow up in 1 year.',
    meds: [{ name: 'Lubricant Eye Drops', strength: '0.5%', freq: 'Four times daily', dur: '30 days' }],
    followUp: '15 Jan 2027',
    advice: 'Limit screen time, use drops daily.',
  },
  {
    id: 'v6',
    dx: 'Dental cleaning & filling',
    doctor: 'Dr. Nadia Malik',
    specialty: 'Dental',
    hospital: 'Aga Khan University Hospital',
    dateLabel: '05 Dec 2025',
    time: '10:30',
    symptoms: 'Sensitivity to cold water on upper right molar.',
    diagnosis: 'Dental caries (K02.9)',
    diagnosisNote: 'Composite filling done on tooth 14. Excellent oral hygiene.',
    meds: [{ name: 'Amoxicillin', strength: '500 mg', freq: 'Three times daily', dur: '5 days' }],
    followUp: '05 Jun 2026',
    advice: 'Brush twice daily, floss daily.',
  },
  {
    id: 'v7',
    dx: 'Knee pain evaluation',
    doctor: 'Dr. Tariq Mahmood',
    specialty: 'Orthopedics',
    hospital: 'CMH Lahore',
    dateLabel: '12 Nov 2025',
    time: '12:15',
    symptoms: 'Mild pain in right knee after walking long distances.',
    diagnosis: 'Osteoarthritis of knee, unspecified (M17.9)',
    diagnosisNote: 'Early stage OA. Recommended physical therapy.',
    meds: [{ name: 'Glucosamine', strength: '1500 mg', freq: 'Once daily', dur: 'Ongoing' }],
    followUp: '12 May 2026',
    advice: 'Avoid high-impact activities, knee support sleeve.',
  },
];

const prescriptions = [
  {
    id: 'rx1',
    name: 'Amlodipine',
    strength: '5 mg',
    freq: 'Once daily',
    dur: '30 days',
    by: 'Dr. Imran Yousuf',
    date: '18 Jun',
    active: true,
  },
  {
    id: 'rx2',
    name: 'Metformin',
    strength: '500 mg',
    freq: 'Twice daily',
    dur: 'Ongoing',
    by: 'Dr. Sana Tariq',
    date: '02 May',
    active: true,
  },
  {
    id: 'rx3',
    name: 'Aspirin',
    strength: '75 mg',
    freq: 'Once daily',
    dur: '30 days',
    by: 'Dr. Imran Yousuf',
    date: '18 Jun',
    active: true,
    warn: 'Avoid with Penicillin-class drugs',
  },
  {
    id: 'rx4',
    name: 'Pantoprazole',
    strength: '40 mg',
    freq: 'Once daily',
    dur: 'Completed',
    by: 'Dr. Imran Yousuf',
    date: '21 Mar',
    active: false,
  },
];

const reports = [
  { id: 'r1', name: 'Lipid Profile', lab: 'Shifa Lab', date: '18 Jun 2026', status: 'ready' },
  { id: 'r2', name: 'HbA1c', lab: 'Shifa Lab', date: '18 Jun 2026', status: 'ready' },
  { id: 'r3', name: 'Chest X-Ray', lab: 'Aga Khan', date: '02 May 2026', status: 'reviewed' },
  { id: 'r4', name: 'Fasting Blood Sugar', lab: 'Chughtai Lab', date: '02 May 2026', status: 'abnormal' },
];

const conversations = [
  {
    doctorId: 'imran',
    initials: 'IY',
    name: 'Dr. Imran Yousuf',
    last: 'Yes, same dose. I’ve added it to your…',
    time: '09:21',
    unread: 1,
    online: true,
    messages: [
      { text: 'Your BP readings look stable. Keep logging twice daily.', fromMe: false, time: '09:12' },
      { text: 'Thank you doctor. Should I continue Amlodipine?', fromMe: true, time: '09:20' },
      { text: 'Yes, same dose. I’ve added it to your prescriptions.', fromMe: false, time: '09:21' },
    ],
  },
  {
    doctorId: 'sana',
    initials: 'ST',
    name: 'Dr. Sana Tariq',
    last: 'Your HbA1c looks much better.',
    time: 'Yesterday',
    unread: 0,
    online: false,
    messages: [
      { text: 'I uploaded my fasting sugar log for the week.', fromMe: true, time: '18:02' },
      { text: 'Your HbA1c looks much better. Well done!', fromMe: false, time: '18:30' },
    ],
  },
  {
    doctorId: 'care',
    initials: 'SC',
    name: 'Sehat Care Team',
    last: 'Welcome to Sehat ID 👋',
    time: 'Mon',
    unread: 0,
    online: false,
    messages: [
      { text: 'Welcome to Sehat ID 👋 We’re here if you need anything.', fromMe: false, time: 'Mon' },
    ],
  },
];

// Helper to authenticate token
const getUserIdFromToken = (req) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  const token = authHeader.substring(7); // Remove 'Bearer '
  if (token.startsWith('demo_token_')) {
    return token.replace('demo_token_', '');
  }
  return null;
};

// Request Logging Middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// --- API ROUTES ---

// 1. Login Route
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ message: 'Email/phone and password are required' });
  }

  const emailTrim = email.trim().toLowerCase();
  const user = users.find(
    (u) =>
      (u.email.toLowerCase() === emailTrim || u.phone === emailTrim) &&
      u.password === password
  );

  if (!user) {
    return res.status(401).json({ message: 'Invalid email/phone or password' });
  }

  console.log(`User logged in successfully: ${user.email}`);
  res.status(200).json({
    token: `demo_token_${user.id}`,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      healthId: user.healthId,
      dob: user.dob,
      gender: user.gender,
      bloodGroup: user.bloodGroup,
    },
  });
});

// 2. Register Route
app.post('/api/auth/register', (req, res) => {
  const { name, email, password, phone, dob, gender, bloodGroup } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({ message: 'Name, email and password are required' });
  }

  const emailTrim = email.trim().toLowerCase();
  const exists = users.some(
    (u) =>
      u.email.toLowerCase() === emailTrim ||
      (phone && u.phone === phone)
  );

  if (exists) {
    return res.status(400).json({ message: 'User with this email or phone already exists' });
  }

  // Generate new user ID and health ID
  const newId = `user_${Date.now()}`;
  // Simulating the Dart code hash code calculation for health ID
  let charHash = 0;
  for (let i = 0; i < email.length; i++) {
    charHash = (charHash << 5) - charHash + email.charCodeAt(i);
    charHash |= 0; // Convert to 32bit integer
  }
  const positiveHash = Math.abs(charHash) % 10000;
  const healthId = `PK-HC-${positiveHash.toString().padStart(4, '0')}`;

  const newUser = {
    id: newId,
    name,
    email,
    password,
    phone: phone || '',
    healthId,
    dob: dob || '14 Mar 1958',
    gender: gender || 'Male',
    bloodGroup: bloodGroup || 'B+',
  };

  users.push(newUser);
  console.log(`New user registered: ${email} (HealthID: ${healthId})`);

  res.status(201).json({
    token: `demo_token_${newId}`,
    user: {
      id: newUser.id,
      name: newUser.name,
      email: newUser.email,
      phone: newUser.phone,
      healthId: newUser.healthId,
      dob: newUser.dob,
      gender: newUser.gender,
      bloodGroup: newUser.bloodGroup,
    },
  });
});

// 3. Visits Route
app.get('/api/patient/visits', (req, res) => {
  const userId = getUserIdFromToken(req);
  if (!userId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  // If the demo user requests, return the mock list. For other users, return empty list.
  if (userId === 'user_demo_id') {
    return res.status(200).json(visits);
  }
  res.status(200).json([]);
});

// 4. Prescriptions Route
app.get('/api/patient/prescriptions', (req, res) => {
  const userId = getUserIdFromToken(req);
  if (!userId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  if (userId === 'user_demo_id') {
    return res.status(200).json(prescriptions);
  }
  res.status(200).json([]);
});

// 5. Reports Route
app.get('/api/patient/reports', (req, res) => {
  const userId = getUserIdFromToken(req);
  if (!userId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  if (userId === 'user_demo_id') {
    return res.status(200).json(reports);
  }
  res.status(200).json([]);
});

// 6. Conversations Route
app.get('/api/patient/conversations', (req, res) => {
  const userId = getUserIdFromToken(req);
  if (!userId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  if (userId === 'user_demo_id') {
    return res.status(200).json(conversations);
  }
  // Newly registered users get a welcome chat from Sehat Care Team
  res.status(200).json([
    {
      doctorId: 'care',
      initials: 'SC',
      name: 'Sehat Care Team',
      last: 'Welcome to Sehat ID 👋',
      time: 'Just now',
      unread: 0,
      online: false,
      messages: [
        { text: 'Welcome to Sehat ID 👋 We’re here if you need anything.', fromMe: false, time: 'Just now' },
      ],
    }
  ]);
});

// 7. Chat Send Message Route
app.post('/api/patient/chat/send', (req, res) => {
  const userId = getUserIdFromToken(req);
  if (!userId) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  const { doctorId, message } = req.body;
  if (!doctorId || !message) {
    return res.status(400).json({ message: 'doctorId and message are required' });
  }

  const now = new Date();
  const timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

  const sentMessage = {
    text: message,
    fromMe: true,
    time: timeStr,
  };

  // If this is our demo user, append message to conversation to persist it
  if (userId === 'user_demo_id') {
    const convo = conversations.find((c) => c.doctorId === doctorId);
    if (convo) {
      convo.messages.push(sentMessage);
      convo.last = message;
      convo.time = timeStr;
    }
  }

  console.log(`Message sent to doctor ${doctorId}: "${message}"`);
  res.status(201).json(sentMessage);
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`=========================================`);
  console.log(` SehatID Backend Service Running Locally`);
  console.log(` Port: ${PORT}`);
  console.log(` Listen Address: 0.0.0.0 (All interfaces)`);
  console.log(` Wi-Fi Access: http://192.168.100.4:${PORT}`);
  console.log(` Ethernet/VirtualBox: http://192.168.56.1:${PORT}`);
  console.log(`=========================================`);
});
