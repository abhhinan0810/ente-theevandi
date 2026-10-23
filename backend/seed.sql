-- Kerala Railway Corridor Seed Data (Chengannur, Kollam, Ernakulam)

-- 1. Stations Seed (Kerala Corridor)
INSERT INTO stations(code, name, latitude, longitude) VALUES
('TVC', 'Thiruvananthapuram Central', 8.4875, 76.9525),
('QLN', 'Kollam Junction', 8.8870, 76.5956),
('KYJ', 'Kayamkulam Junction', 9.1724, 76.5008),
('MVLK', 'Mavelikara', 9.2483, 76.5471),
('CNGR', 'Chengannur', 9.3178, 76.6186),
('TRVL', 'Tiruvalla', 9.3835, 76.5746),
('CGY', 'Changanassery', 9.4443, 76.5415),
('KTYM', 'Kottayam', 9.5916, 76.5222),
('ERN', 'Ernakulam Town', 9.9816, 76.2999),
('ERS', 'Ernakulam Junction', 9.9680, 76.2890),
('SRR', 'Shoranur Junction', 10.7602, 76.2783)
ON CONFLICT (code) DO UPDATE SET 
  name = EXCLUDED.name,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude;

-- 2. Trains Seed (Real-life Kerala Trains)
INSERT INTO trains(number, name, origin, destination, length_meters) VALUES 
('16302', 'Venad Express', 'Thiruvananthapuram (TVC)', 'Shoranur (SRR)', 480.0),
('16301', 'Venad Express (Down)', 'Shoranur (SRR)', 'Thiruvananthapuram (TVC)', 480.0),
('16650', 'Parasuram Express', 'Nagercoil (NCJ)', 'Mangaluru Central (MAQ)', 480.0),
('16304', 'Vanchinad Express', 'Thiruvananthapuram (TVC)', 'Ernakulam Jn (ERS)', 450.0),
('12626', 'Kerala Express', 'New Delhi (NDLS)', 'Thiruvananthapuram (TVC)', 550.0),
('16629', 'Malabar Express', 'Mangaluru Central (MAQ)', 'Thiruvananthapuram (TVC)', 520.0)
ON CONFLICT (number) DO UPDATE SET
  name = EXCLUDED.name,
  origin = EXCLUDED.origin,
  destination = EXCLUDED.destination,
  length_meters = EXCLUDED.length_meters;

-- 3. Coaches Seed for 16302 Venad Express
-- Formation: ENGINE -> GS1 -> GS2 -> D1 -> D2 -> CC1 -> D3 -> GS3 -> GS4
DELETE FROM coaches WHERE train_id IN (SELECT id FROM trains WHERE number IN ('16302', '16304', '16650', '12626'));

INSERT INTO coaches(train_id, coach_code, coach_type, sequence_no, is_general, distance_from_front, length_meters)
SELECT t.id, x.code, x.type, x.seq, x.general, (x.seq * 24.0), 24.0
FROM trains t
CROSS JOIN (VALUES
  ('ENGINE', 'Locomotive', 0, FALSE),
  ('GS1', 'General Second', 1, TRUE),
  ('GS2', 'General Second', 2, TRUE),
  ('D1', 'Second Sitting (2S)', 3, FALSE),
  ('D2', 'Second Sitting (2S)', 4, FALSE),
  ('CC1', 'AC Chair Car', 5, FALSE),
  ('D3', 'Second Sitting (2S)', 6, FALSE),
  ('GS3', 'General Second', 7, TRUE),
  ('GS4', 'General Second', 8, TRUE)
) AS x(code, type, seq, general)
WHERE t.number='16302';

-- Coaches for 16650 Parasuram Express
INSERT INTO coaches(train_id, coach_code, coach_type, sequence_no, is_general, distance_from_front, length_meters)
SELECT t.id, x.code, x.type, x.seq, x.general, (x.seq * 24.0), 24.0
FROM trains t
CROSS JOIN (VALUES
  ('ENGINE', 'Locomotive', 0, FALSE),
  ('GS1', 'General Second', 1, TRUE),
  ('GS2', 'General Second', 2, TRUE),
  ('D1', 'Second Sitting (2S)', 3, FALSE),
  ('D2', 'Second Sitting (2S)', 4, FALSE),
  ('CC1', 'AC Chair Car', 5, FALSE),
  ('GS3', 'General Second', 6, TRUE),
  ('GS4', 'General Second', 7, TRUE)
) AS x(code, type, seq, general)
WHERE t.number='16650';

-- Coaches for 16304 Vanchinad Express
INSERT INTO coaches(train_id, coach_code, coach_type, sequence_no, is_general, distance_from_front, length_meters)
SELECT t.id, x.code, x.type, x.seq, x.general, (x.seq * 24.0), 24.0
FROM trains t
CROSS JOIN (VALUES
  ('ENGINE', 'Locomotive', 0, FALSE),
  ('GS1', 'General Second', 1, TRUE),
  ('GS2', 'General Second', 2, TRUE),
  ('D1', 'Second Sitting (2S)', 3, FALSE),
  ('D2', 'Second Sitting (2S)', 4, FALSE),
  ('GS3', 'General Second', 5, TRUE)
) AS x(code, type, seq, general)
WHERE t.number='16304';

-- Coaches for 12626 Kerala Express
INSERT INTO coaches(train_id, coach_code, coach_type, sequence_no, is_general, distance_from_front, length_meters)
SELECT t.id, x.code, x.type, x.seq, x.general, (x.seq * 24.0), 24.0
FROM trains t
CROSS JOIN (VALUES
  ('ENGINE', 'Locomotive', 0, FALSE),
  ('GS1', 'General Second', 1, TRUE),
  ('GS2', 'General Second', 2, TRUE),
  ('SL1', 'Sleeper Class', 3, FALSE),
  ('SL2', 'Sleeper Class', 4, FALSE),
  ('3A1', 'AC 3 Tier', 5, FALSE),
  ('2A1', 'AC 2 Tier', 6, FALSE),
  ('GS3', 'General Second', 7, TRUE)
) AS x(code, type, seq, general)
WHERE t.number='12626';

-- 4. Station Platforms Seed (Chengannur, Kottayam, Kollam, Ernakulam)
DELETE FROM station_platforms WHERE station_name IN ('Chengannur', 'Kottayam', 'Kollam Junction', 'Ernakulam Town');

INSERT INTO station_platforms(station_name, platform_number, start_lat, start_lng, end_lat, end_lng) VALUES
('Chengannur', 1, 9.3174, 76.6180, 9.3182, 76.6192),
('Chengannur', 2, 9.3175, 76.6182, 9.3183, 76.6194),
('Chengannur', 3, 9.3176, 76.6184, 9.3184, 76.6196),
('Kollam Junction', 1, 8.8865, 76.5950, 8.8875, 76.5962),
('Kottayam', 1, 9.5910, 76.5215, 9.5922, 76.5229),
('Ernakulam Town', 2, 9.9810, 76.2990, 9.9822, 76.3008);

-- 5. Stopping Profiles (Platform 2 at Chengannur)
DELETE FROM stopping_profiles WHERE station_name = 'Chengannur';

INSERT INTO stopping_profiles(train_id, station_name, platform_number, front_lat, front_lng, heading_deg, avg_coach_length_meters)
SELECT t.id, 'Chengannur', 2, 9.31755, 76.61825, 45.0, 24.0
FROM trains t WHERE t.number='16302';

-- 6. Live Simulated Train Locations
DELETE FROM train_locations WHERE train_id IN (SELECT id FROM trains WHERE number IN ('16302', '16650', '16304'));

INSERT INTO train_locations(train_id, current_station, next_station, latitude, longitude, speed_kmh, status, is_simulated)
SELECT t.id, 'Mavelikara', 'Chengannur', 9.2780, 76.5820, 78.0, 'APPROACHING_STATION', TRUE
FROM trains t WHERE t.number='16302';

INSERT INTO train_locations(train_id, current_station, next_station, latitude, longitude, speed_kmh, status, is_simulated)
SELECT t.id, 'Tiruvalla', 'Chengannur', 9.3500, 76.5960, 65.0, 'IN_TRANSIT', TRUE
FROM trains t WHERE t.number='16650';

INSERT INTO train_locations(train_id, current_station, next_station, latitude, longitude, speed_kmh, status, is_simulated)
SELECT t.id, 'Kollam Junction', 'Kayamkulam', 8.9500, 76.5500, 82.0, 'IN_TRANSIT', TRUE
FROM trains t WHERE t.number='16304';

-- 7. Realistic Sample Crowd Reports for Venad Express (16302) at Chengannur
DELETE FROM crowd_reports WHERE station_name = 'Chengannur';

INSERT INTO crowd_reports(coach_id, station_name, level, created_at, source)
SELECT c.id, 'Chengannur', x.lvl, NOW() - (x.mins || ' minutes')::INTERVAL, 'USER'
FROM coaches c
JOIN trains t ON c.train_id = t.id
CROSS JOIN (VALUES
  ('GS1', 'High', 8),
  ('GS1', 'High', 4),
  ('GS1', 'Medium', 2),
  ('GS2', 'High', 12),
  ('GS2', 'High', 6),
  ('GS2', 'High', 1),
  ('GS3', 'Medium', 15),
  ('GS3', 'Medium', 5),
  ('GS4', 'Low', 18),
  ('GS4', 'Low', 3)
) AS x(code, lvl, mins)
WHERE t.number='16302' AND c.coach_code = x.code;
