# Database Schema Documentation

## Overview
This document outlines the current schema of the `wheelhours` database, including tables and their relationships. It is intended to serve as a reference for developers working on the project.

## Tables

### users
- **id**: Primary key, auto-incrementing integer.
- **username**: Unique identifier for each user.
- **email**: Email address of the user.
- **password_hash**: Hashed version of the user's password.
- **created_at**: Timestamp when the user was created.
- **updated_at**: Timestamp when the user was last updated.
- **version**: Version number to track changes.

### project_tracking
- **id**: Primary key, auto-incrementing integer.
- **project_name**: Name of the project.
- **start_date**: Start date of the project.
- **end_date**: End date of the project.
- **status**: Status of the project (active or inactive).
- **created_at**: Timestamp when the project was created.
- **updated_at**: Timestamp when the project was last updated.

## Version Control
The `users` table includes a `version` column to track changes made to user records. A trigger named `update_user_version` is used to automatically increment the version number every time a record in the `users` table is updated.
