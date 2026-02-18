CREATE TABLE IF NOT EXISTS activity_logs_v2 (
    id BIGSERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    domain VARCHAR(255),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration_seconds BIGINT,
    device_id VARCHAR(255) NOT NULL DEFAULT 'unknown'
);

CREATE TABLE IF NOT EXISTS employees (
    device_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    department VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS domain_categories (
    domain VARCHAR(255) PRIMARY KEY,
    category VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS app_users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_user_email ON activity_logs_v2(user_email);
CREATE INDEX IF NOT EXISTS idx_activity_start_time ON activity_logs_v2(start_time);
CREATE INDEX IF NOT EXISTS idx_activity_device_id ON activity_logs_v2(device_id);
