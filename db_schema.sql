-- SQL script to update database schema

-- Adding new table for project tracking
CREATE TABLE IF NOT EXISTS project_tracking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    start_date DATE,
    end_date DATE,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Updating existing table to include version control information
ALTER TABLE users ADD COLUMN version INT DEFAULT 1;

-- Adding trigger for version control
DELIMITER $$
CREATE TRIGGER update_user_version
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.version = OLD.version + 1;
END$$
DELIMITER ;
