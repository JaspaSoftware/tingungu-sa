const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

let db;

function getAccessTokenFromRefreshToken(refreshToken) {
  return new Promise((resolve, reject) => {
    const postData = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com'
    }).toString();

    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.access_token) {
            resolve(parsed.access_token);
          } else {
            reject(new Error('No access token in response: ' + data));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function initFirebase() {
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    db = admin.firestore();
    return;
  }

  console.log('serviceAccountKey.json not found. Attempting to initialize using Firebase CLI access token...');
  let accessToken;
  try {
    const homeDir = require('os').homedir();
    const configPath = path.join(homeDir, '.config/configstore/firebase-tools.json');
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      if (config.tokens && config.tokens.access_token) {
        accessToken = config.tokens.access_token;
      }
    }
  } catch (err) {
    console.log('Error reading config file:', err.message);
  }

  if (accessToken) {
    try {
      admin.initializeApp({
        credential: {
          getAccessToken: () => Promise.resolve({
            expires_in: 3599,
            access_token: accessToken
          })
        },
        projectId: 'tingungu-sa'
      });
      db = admin.firestore();
      console.log('Firebase Admin initialized successfully with Firebase CLI access token.');
      return;
    } catch (err) {
      console.error('Failed to initialize Firebase Admin with access token:', err.message);
    }
  }

  console.log('Attempting initialization with default credentials...');
  admin.initializeApp({
    projectId: 'tingungu-sa'
  });
  db = admin.firestore();
}

const districts = [
  { id: '1', name: 'Limpopo' }
];

const categories = [
  { id: '1', name: 'District Bishop' },
  { id: '2', name: 'Superintendent' },
  { id: '3', name: 'Ordained' },
  { id: '4', name: 'Probationer' },
  { id: '5', name: 'Chaplain/Ordained' }
];

const circuits = [
  { id: '1', code: '1100', name: 'Limpopo', district_id: '1' },
  { id: '2', code: '1101', name: 'Central', district_id: '1' },
  { id: '3', code: '1102', name: 'Moreleta', district_id: '1' },
  { id: '4', code: '1103', name: 'Magalies', district_id: '1' },
  { id: '5', code: '1105', name: 'Hennops', district_id: '1' },
  { id: '6', code: '1106', name: 'Coalfields', district_id: '1' },
  { id: '7', code: '1107', name: 'Maranatha', district_id: '1' },
  { id: '8', code: '1108', name: 'Middleburg', district_id: '1' },
  { id: '9', code: '1109', name: 'Escarpment', district_id: '1' },
  { id: '10', code: '1111', name: 'Pilanesburg', district_id: '1' },
  { id: '11', code: '1112', name: 'Platinum', district_id: '1' },
  { id: '12', code: '1113', name: 'Mabieskraal', district_id: '1' },
  { id: '13', code: '1114', name: 'Wabela', district_id: '1' },
  { id: '14', code: '1115', name: 'Temba', district_id: '1' },
  { id: '15', code: '1116', name: 'Makapan', district_id: '1' },
  { id: '16', code: '1117', name: 'Lebotloane', district_id: '1' },
  { id: '17', code: '1118', name: 'Soutpansburg', district_id: '1' },
  { id: '18', code: '1119', name: 'Ysterberg', district_id: '1' },
  { id: '19', code: '1120', name: 'Letaba', district_id: '1' },
  { id: '20', code: '1121', name: 'Mbombela', district_id: '1' },
  { id: '21', code: '1122', name: 'Mhluzi', district_id: '1' },
  { id: '22', code: '1123', name: 'Sabie and Shateli', district_id: '1' },
  { id: '23', code: '1124', name: 'Lowveld', district_id: '1' },
  { id: '24', code: '1125', name: 'Nkomazi', district_id: '1' },
  { id: '25', code: '1129', name: 'Capricorn West', district_id: '1' },
  { id: '26', code: '1130', name: 'Capricorn East', district_id: '1' },
  { id: '27', code: '1131', name: 'Soshanguve', district_id: '1' },
  { id: '28', code: '1132', name: 'Mogalakwena', district_id: '1' },
  { id: '29', code: '1133', name: 'Zebediela', district_id: '1' },
  { id: '30', code: '1134', name: 'Mphahlele', district_id: '1' },
  { id: '31', code: '1135', name: 'Sekhukhune', district_id: '1' },
  { id: '32', code: '1136', name: 'Northern ODI', district_id: '1' },
  { id: '33', code: '1137', name: 'Mabopane', district_id: '1' },
  { id: '34', code: '1138', name: 'Ga-Rankuwa', district_id: '1' }
];

const societies = [
  { id: '1', name: 'Willows', circuit_id: '2' },
  { id: '2', name: 'Atteridgeville', circuit_id: '2' },
  { id: '3', name: 'Sunnyside', circuit_id: '2' },
  { id: '4', name: 'Saulsville', circuit_id: '2' },
  { id: '5', name: 'Brooklyn', circuit_id: '2' },
  { id: '6', name: 'Pta Central', circuit_id: '2' },
  { id: '7', name: 'The Glen', circuit_id: '3' },
  { id: '8', name: 'Eastview', circuit_id: '3' },
  { id: '9', name: 'Eersterust', circuit_id: '3' },
  { id: '10', name: 'Brooklyn', circuit_id: '3' },
  { id: '11', name: 'St Georges', circuit_id: '3' },
  { id: '12', name: 'Mamelodi East', circuit_id: '3' },
  { id: '13', name: 'Mamelodi Central', circuit_id: '3' },
  { id: '14', name: 'Valley', circuit_id: '4' },
  { id: '15', name: 'Sinoville', circuit_id: '4' },
  { id: '16', name: 'Pta North & Trinity', circuit_id: '4' },
  { id: '17', name: 'Trinity', circuit_id: '4' },
  { id: '18', name: 'Midstream', circuit_id: '5' },
  { id: '19', name: 'Westview', circuit_id: '5' },
  { id: '20', name: 'Elim', circuit_id: '5' },
  { id: '21', name: 'Gracewell', circuit_id: '5' },
  { id: '22', name: 'Lyttleton', circuit_id: '5' },
  { id: '23', name: 'Mnandi/St John\'s', circuit_id: '5' },
  { id: '24', name: 'Coalfields', circuit_id: '6' },
  { id: '25', name: 'Kungwini', circuit_id: '6' },
  { id: '26', name: 'Siyabuswa', circuit_id: '7' },
  { id: '27', name: 'Middleburg', circuit_id: '8' },
  { id: '28', name: 'Groblersdal', circuit_id: '8' },
  { id: '29', name: 'Lydenburg & Sabie', circuit_id: '9' },
  { id: '30', name: 'Rustenburg/Mooinooi', circuit_id: '10' },
  { id: '31', name: 'Geelhout Park', circuit_id: '10' },
  { id: '32', name: 'Thlabane', circuit_id: '10' },
  { id: '33', name: 'Ebenezer', circuit_id: '11' },
  { id: '34', name: 'Bethel', circuit_id: '11' },
  { id: '35', name: 'Mabieskraal', circuit_id: '12' },
  { id: '36', name: 'Belabela', circuit_id: '13' },
  { id: '37', name: 'Waterberg', circuit_id: '13' },
  { id: '38', name: 'Temba', circuit_id: '14' },
  { id: '39', name: 'Makapan', circuit_id: '15' },
  { id: '40', name: 'Lebotloane', circuit_id: '16' },
  { id: '41', name: 'Ha-Tshikota', circuit_id: '17' },
  { id: '42', name: 'Louis Trichard', circuit_id: '17' },
  { id: '43', name: 'Ysterberg', circuit_id: '18' },
  { id: '44', name: 'Wesley', circuit_id: '18' },
  { id: '45', name: 'Aldersgate', circuit_id: '18' },
  { id: '46', name: 'Tzaneen', circuit_id: '19' },
  { id: '47', name: 'Namakgale//Nkowankowa', circuit_id: '19' },
  { id: '48', name: 'Phalaborwa', circuit_id: '19' },
  { id: '49', name: 'Lekazi', circuit_id: '20' },
  { id: '50', name: 'Kabokweni', circuit_id: '20' },
  { id: '51', name: 'White River', circuit_id: '20' },
  { id: '52', name: 'Penryn', circuit_id: '20' },
  { id: '53', name: 'Mhluzi', circuit_id: '21' },
  { id: '54', name: 'Sabie and Shateli', circuit_id: '22' },
  { id: '55', name: 'John Wesley/Lowveld', circuit_id: '23' },
  { id: '56', name: 'Barberton', circuit_id: '23' },
  { id: '57', name: 'Nkomazi', circuit_id: '24' },
  { id: '58', name: 'Capricorn West', circuit_id: '25' },
  { id: '59', name: 'Capricorn East', circuit_id: '26' },
  { id: '60', name: 'Soshanguve', circuit_id: '27' },
  { id: '61', name: 'Mogalakwena', circuit_id: '28' },
  { id: '62', name: 'Zebediela', circuit_id: '29' },
  { id: '63', name: 'Mphahlele', circuit_id: '30' },
  { id: '64', name: 'Sekhukhune', circuit_id: '31' },
  { id: '65', name: 'Northern ODI', circuit_id: '32' },
  { id: '66', name: 'Willowbrook', circuit_id: '33' },
  { id: '67', name: 'Mabopane', circuit_id: '33' },
  { id: '68', name: 'Ga-Rankuwa', circuit_id: '34' }
];

const persons = [
  { id: '1', surname: 'MOKGOTHU', first_name: 'SIDWELL', cellphone: '0829654807', email: 'bishop@mcsalimpopo.co.za' },
  { id: '2', surname: 'MERCER', first_name: 'GRAEME', cellphone: '0829263798', email: 'graeme.mercer@willows.org.za' },
  { id: '3', surname: 'BOSMAN', first_name: 'SMANGA', cellphone: '0829263798', email: 'smanga@glenmethodist.co.za' },
  { id: '4', surname: 'MNTAMBO', first_name: 'KEDIBONE', cellphone: '0725915145', email: 'revk.valley.mc@gmail.com' },
  { id: '5', surname: 'RAMAGE', first_name: 'JAMES', cellphone: '0834591947', email: 'jim@midstreammethodist.org.za' },
  { id: '6', surname: 'KOEKOE', first_name: 'PHEZILE', cellphone: '0782954396', email: 'phzlkoekoe@yahoo.com' },
  { id: '7', surname: 'PHUNGULA', first_name: 'NOMVULA', cellphone: '0790278129', email: 'cyrilphungula@gmail.com' },
  { id: '8', surname: 'NTSHUNTSHE', first_name: 'THANDUXOLO', cellphone: '0833457370', email: 'ntshuntshethanduxolo@gmail.com' },
  { id: '9', surname: 'BOOYSEN', first_name: 'TERRY', cellphone: '0835628589', email: 'booysentm@gmail.com' },
  { id: '10', surname: 'MOLYNEUX', first_name: 'ALAN', cellphone: '0824287980', email: 'molyneuxalan@hotmail.com' },
  { id: '11', surname: 'TSHIKITA', first_name: 'MOEKETSI', cellphone: '0839507845', email: 'moeketsitshikita@yahoo.co.za' },
  { id: '12', surname: 'NGWANE', first_name: 'ORAPELENG', cellphone: '0734139965', email: 'totoraps@gmail.com' },
  { id: '13', surname: 'MABITLE', first_name: 'WELCOME', cellphone: null, email: null },
  { id: '14', surname: 'MOLEFI', first_name: 'MORATSHWANYANE', cellphone: '0616074478', email: 'molefimora@gmail.com' },
  { id: '15', surname: 'SELEBALO', first_name: 'MOLATLHEGI', cellphone: '0837259527', email: 'cselebalo@yahoo.com' },
  { id: '16', surname: 'TSHABALALA', first_name: 'MZIMKHULU', cellphone: '0760841868', email: 'ishmael.co.za@gmail.com' },
  { id: '17', surname: 'RADEBE', first_name: 'SPHIWE', cellphone: '0781703146', email: 'sphiweradebe64@gmail.com' },
  { id: '18', surname: 'SEITSHIRO', first_name: 'MMATU', cellphone: '0838094218', email: 'kelebogileseitshiro@gmail.com' },
  { id: '19', surname: 'DAVID', first_name: 'GERTZE', cellphone: '0814239490', email: 'davidgertze@gmail.com' },
  { id: '20', surname: 'TAU', first_name: 'MOLEFI', cellphone: '0837092012', email: 'tau.molefi@yahoo.com' },
  { id: '21', surname: 'MANAMELA', first_name: 'THUSHO', cellphone: '0721484933', email: 'thushommaphuti@yahoo.com' },
  { id: '22', surname: 'STEYN', first_name: 'ROXANNE', cellphone: '0795450273', email: 'roxfrog@gmail.com' },
  { id: '23', surname: 'SEKHEJANE', first_name: 'MOAGI', cellphone: '832929655', email: 'msekhejane@gmail.com' },
  { id: '24', surname: 'MTHOMBENI', first_name: 'ZACHARIA', cellphone: '0829765288', email: 'sakimtho@gmail.com' },
  { id: '25', surname: 'MOEMA', first_name: 'EDITH', cellphone: '0761865246', email: 'notty.moema@yahoo.co.uk' },
  { id: '26', surname: 'RADEBE', first_name: 'ZAKHELE', cellphone: '0820797965', email: 'radebeze@gmail.com' },
  { id: '27', surname: 'NGWENYA', first_name: 'MBONGENI', cellphone: '0746293111', email: 'mbongenivcngwenya@gmail.com' },
  { id: '28', surname: 'VILAKAZI', first_name: 'BONGANI', cellphone: null, email: null },
  { id: '29', surname: 'MANNE', first_name: 'BURNETT', cellphone: '0798519162', email: 'burnettmmamolelemanne@gmail.com' },
  { id: '30', surname: 'SEEKOEI', first_name: 'MOSIGA', cellphone: '0732170823', email: 'kubu.seekoei@gmail.com' },
  { id: '31', surname: 'KGOTLE', first_name: 'THLAOLE', cellphone: '0723090869', email: 'kgotletj@gmail.com' },
  { id: '32', surname: 'NTWAGAE', first_name: 'JOHANNES', cellphone: '0824306965', email: 'jsntwagae@gmail.com' },
  { id: '33', surname: 'MOEKETSI', first_name: 'ELISHA', cellphone: '0837371206', email: 'moeketsi.me@gmail.com' },
  { id: '34', surname: 'MADUMO', first_name: 'PETRUS', cellphone: '0723986960', email: 'madumop@yahoo.co' },
  { id: '35', surname: 'DITHUGE', first_name: 'THOKWANE', cellphone: '0722619446', email: 'dithuge@gmail.com' },
  { id: '36', surname: 'MONAGENG', first_name: 'LETHULE', cellphone: '0732628951', email: 'revmonageng@gmail.com' },
  { id: '37', surname: 'DIETSISO', first_name: 'MOKGETHI', cellphone: '0835116250', email: 'mokgethidietsiso@telkom.net' }
];

const appointments = [
  { person_id: '1', society_id: '1', category_id: '1' },
  { person_id: '2', society_id: '1', category_id: '2' },
  { person_id: '3', society_id: '7', category_id: '2' },
  { person_id: '4', society_id: '14', category_id: '2' },
  { person_id: '5', society_id: '18', category_id: '2' },
  { person_id: '6', society_id: '24', category_id: '2' },
  { person_id: '7', society_id: '25', category_id: '4' },
  { person_id: '8', society_id: '26', category_id: '2' },
  { person_id: '9', society_id: '27', category_id: '2' },
  { person_id: '10', society_id: '30', category_id: '2' },
  { person_id: '11', society_id: '33', category_id: '2' },
  { person_id: '12', society_id: '35', category_id: '2' },
  { person_id: '13', society_id: '36', category_id: '2' },
  { person_id: '14', society_id: '38', category_id: '2' },
  { person_id: '15', society_id: '39', category_id: '2' },
  { person_id: '16', society_id: '40', category_id: '2' },
  { person_id: '17', society_id: '41', category_id: '2' },
  { person_id: '18', society_id: '43', category_id: '2' },
  { person_id: '19', society_id: '46', category_id: '2' },
  { person_id: '20', society_id: '49', category_id: '2' },
  { person_id: '21', society_id: '50', category_id: '3' },
  { person_id: '22', society_id: '51', category_id: '4' },
  { person_id: '23', society_id: '52', category_id: '5' },
  { person_id: '24', society_id: '53', category_id: '2' },
  { person_id: '25', society_id: '54', category_id: '2' },
  { person_id: '26', society_id: '55', category_id: '2' },
  { person_id: '27', society_id: '57', category_id: '2' },
  { person_id: '29', society_id: '58', category_id: '2' },
  { person_id: '30', society_id: '59', category_id: '2' },
  { person_id: '31', society_id: '60', category_id: '2' },
  { person_id: '32', society_id: '61', category_id: '2' },
  { person_id: '33', society_id: '62', category_id: '2' },
  { person_id: '34', society_id: '63', category_id: '2' },
  { person_id: '35', society_id: '64', category_id: '2' },
  { person_id: '36', society_id: '65', category_id: '2' },
  { person_id: '37', society_id: '68', category_id: '2' }
];

async function seed() {
  await initFirebase();
  console.log('Starting seed process...');

  // Seed Districts
  for (const district of districts) {
    await db.collection('districts').doc(district.id).set({
      name: district.name,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log('Districts seeded.');

  // Seed Categories
  for (const cat of categories) {
    await db.collection('categories').doc(cat.id).set({
      name: cat.name
    });
  }
  console.log('Categories seeded.');

  // Seed Circuits
  for (const circuit of circuits) {
    await db.collection('circuits').doc(circuit.id).set({
      code: circuit.code,
      name: circuit.name,
      districtId: circuit.district_id
    });
  }
  console.log('Circuits seeded.');

  // Seed Societies
  for (const society of societies) {
    await db.collection('societies').doc(society.id).set({
      name: society.name,
      circuitId: society.circuit_id
    });
  }
  console.log('Societies seeded.');

  // Seed Persons (Ministers)
  for (const person of persons) {
    await db.collection('ministers').doc(person.id).set({
      surname: person.surname,
      firstName: person.first_name,
      cellphone: person.cellphone,
      email: person.email
    });
  }
  console.log('Ministers seeded.');

  // Seed Appointments
  for (const appt of appointments) {
    await db.collection('appointments').add({
      ministerId: appt.person_id,
      societyId: appt.society_id,
      categoryId: appt.category_id,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log('Appointments seeded.');

  console.log('Seed process completed successfully!');
}

seed().catch(err => {
  console.error('Seed error:', err);
  process.exit(1);
});
