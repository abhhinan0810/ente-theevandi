-- Existing tables
CREATE TABLE IF NOT EXISTS stations (
  id SERIAL PRIMARY KEY,
  code VARCHAR(10) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS trains (
  id SERIAL PRIMARY KEY,
  number VARCHAR(10) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  origin VARCHAR(100) NOT NULL,
  destination VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS coaches (
  id SERIAL PRIMARY KEY,
  train_id INTEGER NOT NULL REFERENCES trains(id) ON DELETE CASCADE,
  coach_code VARCHAR(12) NOT NULL,
  coach_type VARCHAR(30) NOT NULL,
  sequence_no INTEGER NOT NULL,
  is_general BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(train_id, coach_code),
  UNIQUE(train_id, sequence_no)
);

CREATE TABLE IF NOT EXISTS crowd_reports (
  id SERIAL PRIMARY KEY,
  coach_id INTEGER NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  station_name VARCHAR(100) NOT NULL,
  level VARCHAR(10) NOT NULL CHECK (level IN ('Low','Medium','High')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_coach_time ON crowd_reports(coach_id, created_at DESC);

-- Expanded tables for tracking, positioning, and simulation
CREATE TABLE IF NOT EXISTS station_platforms (
  id SERIAL PRIMARY KEY,
  station_name VARCHAR(100) NOT NULL,
  platform_number INTEGER NOT NULL,
  start_lat DOUBLE PRECISION NOT NULL,
  start_lng DOUBLE PRECISION NOT NULL,
  end_lat DOUBLE PRECISION NOT NULL,
  end_lng DOUBLE PRECISION NOT NULL,
  UNIQUE(station_name, platform_number)
);

CREATE TABLE IF NOT EXISTS stopping_profiles (
  id SERIAL PRIMARY KEY,
  train_id INTEGER NOT NULL REFERENCES trains(id) ON DELETE CASCADE,
  station_name VARCHAR(100) NOT NULL,
  platform_number INTEGER NOT NULL,
  front_lat DOUBLE PRECISION NOT NULL,
  front_lng DOUBLE PRECISION NOT NULL,
  heading_deg DOUBLE PRECISION NOT NULL DEFAULT 90.0,
  avg_coach_length_meters DOUBLE PRECISION NOT NULL DEFAULT 24.0,
  UNIQUE(train_id, station_name, platform_number)
);

CREATE TABLE IF NOT EXISTS train_locations (
  id SERIAL PRIMARY KEY,
  train_id INTEGER NOT NULL REFERENCES trains(id) ON DELETE CASCADE UNIQUE,
  current_station VARCHAR(100) NOT NULL,
  next_station VARCHAR(100) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  speed_kmh DOUBLE PRECISION NOT NULL DEFAULT 60.0,
  status VARCHAR(50) NOT NULL DEFAULT 'IN_TRANSIT',
  is_simulated BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS simulated_passengers (
  id SERIAL PRIMARY KEY,
  passenger_name VARCHAR(50) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  assigned_coach_id INTEGER REFERENCES coaches(id) ON DELETE SET NULL,
  last_report_level VARCHAR(10),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
