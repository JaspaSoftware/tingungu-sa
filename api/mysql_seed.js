const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

dotenv.config();

const sqlScript = `
-- =========================================
-- DISTRICTS
-- =========================================
CREATE TABLE IF NOT EXISTS districts (
    district_id INT AUTO_INCREMENT PRIMARY KEY,
    district_name VARCHAR(150) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- CIRCUITS
-- =========================================
CREATE TABLE IF NOT EXISTS circuits (
    circuit_id INT AUTO_INCREMENT PRIMARY KEY,
    circuit_code VARCHAR(20) NOT NULL UNIQUE,
    circuit_name VARCHAR(150) NOT NULL,
    district_id INT,
    FOREIGN KEY (district_id) REFERENCES districts(district_id) ON DELETE SET NULL
);

-- =========================================
-- SOCIETIES
-- =========================================
CREATE TABLE IF NOT EXISTS societies (
    society_id INT AUTO_INCREMENT PRIMARY KEY,
    society_name VARCHAR(150) NOT NULL,
    circuit_id INT NOT NULL,
    FOREIGN KEY (circuit_id) REFERENCES circuits(circuit_id) ON DELETE CASCADE
);

-- =========================================
-- PRODUCTS (MARKETPLACE)
-- =========================================
CREATE TABLE IF NOT EXISTS products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    product_title VARCHAR(255),
    seller_name VARCHAR(150),
    cost_price DECIMAL(10,2),
    selling_price DECIMAL(10,2),
    product_description TEXT,
    category VARCHAR(100),
    stock_quantity INT DEFAULT 0,
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- PERSONS
-- =========================================
CREATE TABLE IF NOT EXISTS persons (
    person_id INT AUTO_INCREMENT PRIMARY KEY,
    surname VARCHAR(100) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    cellphone VARCHAR(30),
    email VARCHAR(255)
);

-- =========================================
-- CATEGORIES
-- =========================================
CREATE TABLE IF NOT EXISTS categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

-- =========================================
-- APPOINTMENTS
-- =========================================
CREATE TABLE IF NOT EXISTS appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    society_id INT NOT NULL,
    category_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (person_id) REFERENCES persons(person_id) ON DELETE CASCADE,
    FOREIGN KEY (society_id) REFERENCES societies(society_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- =========================================
-- SEED DATA
-- =========================================
INSERT IGNORE INTO districts (district_name) VALUES ('Limpopo');

INSERT IGNORE INTO categories (category_name) VALUES
('District Bishop'), ('Superintendent'), ('Ordained'), ('Probationer'), ('Chaplain/Ordained');

INSERT IGNORE INTO circuits (circuit_code, circuit_name, district_id) VALUES
('1100', 'Limpopo', 1), ('1101', 'Central', 1), ('1102', 'Moreleta', 1), ('1103', 'Magalies', 1),
('1105', 'Hennops', 1), ('1106', 'Coalfields', 1), ('1107', 'Maranatha', 1), ('1108', 'Middleburg', 1),
('1109', 'Escarpment', 1), ('1111', 'Pilanesburg', 1), ('1112', 'Platinum', 1), ('1113', 'Mabieskraal', 1),
('1114', 'Wabela', 1), ('1115', 'Temba', 1), ('1116', 'Makapan', 1), ('1117', 'Lebotloane', 1),
('1118', 'Soutpansburg', 1), ('1119', 'Ysterberg', 1), ('1120', 'Letaba', 1), ('1121', 'Mbombela', 1),
('1122', 'Mhluzi', 1), ('1123', 'Sabie and Shateli', 1), ('1124', 'Lowveld', 1), ('1125', 'Nkomazi', 1),
('1129', 'Capricorn West', 1), ('1130', 'Capricorn East', 1), ('1131', 'Soshanguve', 1), ('1132', 'Mogalakwena', 1),
('1133', 'Zebediela', 1), ('1134', 'Mphahlele', 1), ('1135', 'Sekhukhune', 1), ('1136', 'Northern ODI', 1),
('1137', 'Mabopane', 1), ('1138', 'Ga-Rankuwa', 1);

INSERT IGNORE INTO societies (society_name, circuit_id) VALUES
('Willows', 2), ('Atteridgeville', 2), ('Sunnyside', 2), ('Saulsville', 2), ('Brooklyn', 2), ('Pta Central', 2),
('The Glen', 3), ('Eastview', 3), ('Eersterust', 3), ('Brooklyn', 3), ('St Georges', 3), ('Mamelodi East', 3),
('Mamelodi Central', 3), ('Valley', 4), ('Sinoville', 4), ('Pta North & Trinity', 4), ('Trinity', 4),
('Midstream', 5), ('Westview', 5), ('Elim', 5), ('Gracewell', 5), ('Lyttleton', 5), ('Mnandi/St John''s', 5),
('Coalfields', 6), ('Kungwini', 6), ('Siyabuswa', 7), ('Middleburg', 8), ('Groblersdal', 8), ('Lydenburg & Sabie', 9),
('Rustenburg/Mooinooi', 10), ('Geelhout Park', 10), ('Thlabane', 10), ('Ebenezer', 11), ('Bethel', 11),
('Mabieskraal', 12), ('Belabela', 13), ('Waterberg', 13), ('Temba', 14), ('Makapan', 15), ('Lebotloane', 16),
('Ha-Tshikota', 17), ('Louis Trichard', 17), ('Ysterberg', 18), ('Wesley', 18), ('Aldersgate', 18),
('Tzaneen', 19), ('Namakgale//Nkowankowa', 19), ('Phalaborwa', 19), ('Lekazi', 20), ('Kabokweni', 20),
('White River', 20), ('Penryn', 20), ('Mhluzi', 21), ('Sabie and Shateli', 22), ('John Wesley/Lowveld', 23),
('Barberton', 23), ('Nkomazi', 24), ('Capricorn West', 25), ('Capricorn East', 26), ('Soshanguve', 27),
('Mogalakwena', 28), ('Zebediela', 29), ('Mphahlele', 30), ('Sekhukhune', 31), ('Northern ODI', 32),
('Willowbrook', 33), ('Mabopane', 33), ('Ga-Rankuwa', 34);

INSERT IGNORE INTO persons (person_id, surname, first_name, cellphone, email) VALUES
(1, 'MOKGOTHU', 'SIDWELL', '0829654807', 'bishop@mcsalimpopo.co.za'),
(2, 'MERCER', 'GRAEME', '0829263798', 'graeme.mercer@willows.org.za'),
(3, 'BOSMAN', 'SMANGA', '0722673167', 'smanga@glenmethodist.co.za'),
(4, 'MNTAMBO', 'KEDIBONE', '0725915145', 'revk.valley.mc@gmail.com'),
(5, 'RAMAGE', 'JAMES', '0834591947', 'jim@midstreammethodist.org.za'),
(6, 'KOEKOE', 'PHEZILE', '0782954396', 'phzlkoekoe@yahoo.com'),
(7, 'PHUNGULA', 'NOMVULA', '0790278129', 'cyrilphungula@gmail.com'),
(8, 'NTSHUNTSHE', 'THANDUXOLO', '0833457370', 'ntshuntshethanduxolo@gmail.com'),
(9, 'BOOYSEN', 'TERRY', '0835628589', 'booysentm@gmail.com'),
(10, 'MOLYNEUX', 'ALAN', '0824287980', 'molyneuxalan@hotmail.com'),
(11, 'TSHIKITA', 'MOEKETSI', '0839507845', 'moeketsitshikita@yahoo.co.za'),
(12, 'NGWANE', 'ORAPELENG', '0734139965', 'totoraps@gmail.com'),
(13, 'MABITLE', 'WELCOME', NULL, NULL),
(14, 'MOLEFI', 'MORATSHWANYANE', '0616074478', 'molefimora@gmail.com'),
(15, 'SELEBALO', 'MOLATLHEGI', '0837259527', 'cselebalo@yahoo.com'),
(16, 'TSHABALALA', 'MZIMKHULU', '0760841868', 'ishmael.co.za@gmail.com'),
(17, 'RADEBE', 'SPHIWE', '0781703146', 'sphiweradebe64@gmail.com'),
(18, 'SEITSHIRO', 'MMATU', '0838094218', 'kelebogileseitshiro@gmail.com'),
(19, 'DAVID', 'GERTZE', '0814239490', 'davidgertze@gmail.com'),
(20, 'TAU', 'MOLEFI', '0837092012', 'tau.molefi@yahoo.com'),
(21, 'MANAMELA', 'THUSHO', '0721484933', 'thushommaphuti@yahoo.com'),
(22, 'STEYN', 'ROXANNE', '0795450273', 'roxfrog@gmail.com'),
(23, 'SEKHEJANE', 'MOAGI', '832929655', 'msekhejane@gmail.com'),
(24, 'MTHOMBENI', 'ZACHARIA', '0829765288', 'sakimtho@gmail.com'),
(25, 'MOEMA', 'EDITH', '0761865246', 'notty.moema@yahoo.co.uk'),
(26, 'RADEBE', 'ZAKHELE', '0820797965', 'radebeze@gmail.com'),
(27, 'NGWENYA', 'MBONGENI', '0746293111', 'mbongenivcngwenya@gmail.com'),
(28, 'VILAKAZI', 'BONGANI', NULL, NULL),
(29, 'MANNE', 'BURNETT', '0798519162', 'burnettmmamolelemanne@gmail.com'),
(30, 'SEEKOEI', 'MOSIGA', '0732170823', 'kubu.seekoei@gmail.com'),
(31, 'KGOTLE', 'THLAOLE', '0723090869', 'kgotletj@gmail.com'),
(32, 'NTWAGAE', 'JOHANNES', '0824306965', 'jsntwagae@gmail.com'),
(33, 'MOEKETSI', 'ELISHA', '0837371206', 'moeketsi.me@gmail.com'),
(34, 'MADUMO', 'PETRUS', '0723986960', 'madumop@yahoo.co'),
(35, 'DITHUGE', 'THOKWANE', '0722619446', 'dithuge@gmail.com'),
(36, 'MONAGENG', 'LETHULE', '0732628951', 'revmonageng@gmail.com'),
(37, 'DIETSISO', 'MOKGETHI', '0835116250', 'mokgethidietsiso@telkom.net');

INSERT IGNORE INTO appointments (person_id, society_id, category_id) VALUES
(1, 1, 1), (2, 1, 2), (3, 7, 2), (4, 14, 2), (5, 18, 2), (6, 24, 2), (7, 25, 4), (8, 26, 2),
(9, 27, 2), (10, 30, 2), (11, 33, 2), (12, 35, 2), (13, 36, 2), (14, 38, 2), (15, 39, 2),
(16, 40, 2), (17, 41, 2), (18, 43, 2), (19, 46, 2), (20, 49, 2), (21, 50, 3), (22, 51, 4),
(23, 52, 5), (24, 53, 2), (25, 54, 2), (26, 55, 2), (27, 57, 2), (29, 58, 2), (30, 59, 2),
(31, 60, 2), (32, 61, 2), (33, 62, 2), (34, 63, 2), (35, 64, 2), (36, 65, 2), (37, 68, 2);

INSERT IGNORE INTO products (product_name, product_title, seller_name, cost_price, selling_price, product_description, category, stock_quantity) VALUES
('Love & Loving Tumbler Set', 'Bespoke 4pc Tumbler Set', 'Xpressive Culture', 150.00, 250.00, 'A soft, minimalist aesthetic with clean lettering, designed to inspire and promote a mindful home environment.', 'Glassware', 10),
('Bespoke Gifting Box', 'Custom Intentional Gifting', 'Xpressive Culture', 350.00, 550.00, 'Hand-picked artisanal items curated for a special recipient.', 'Gifting', 5),
('Branded Custom Apparel', 'Xpressive Culture Apparel', 'Xpressive Culture', 200.00, 350.00, 'High-quality custom branded apparel for teams or individuals.', 'Clothing', 20),
('Artisanal Glassware Set', 'Hand-crafted Glass Collection', 'Xpressive Culture', 400.00, 650.00, 'Unique, hand-crafted glassware for an elegant home.', 'Glassware', 8);
`;

async function seed() {
  console.log('Connecting to MySQL...');
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true,
    ssl: {
      ca: process.env.DB_SSL_CA ? fs.readFileSync(path.join(__dirname, process.env.DB_SSL_CA)) : undefined,
      rejectUnauthorized: true
    }
  });

  try {
    console.log('Creating database if not exists...');
    await connection.query(`CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME || 'methodist_church_db'}`);
    await connection.query(`USE ${process.env.DB_NAME || 'methodist_church_db'}`);

    console.log('Running DDL and Seeding Data...');
    
    // Split script by semicolon but be careful with data
    const statements = sqlScript.split(';').map(s => s.trim()).filter(s => s.length > 0);
    
    for (const statement of statements) {
      try {
        await connection.query(statement);
      } catch (err) {
        console.error('Statement failed:', statement.substring(0, 50) + '...');
        console.error('Error:', err.message);
      }
    }

    console.log('MySQL Database Seeded Successfully!');
  } catch (err) {
    console.error('MySQL Seeding Error:', err);
  } finally {
    await connection.end();
  }
}

seed();
