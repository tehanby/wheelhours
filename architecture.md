# Initial Architecture Design for WheelHours

## Overview
WheelHours is designed to be a web application that helps users manage their time effectively. The system will include features such as task tracking, time logging, and project management.

## Components

1. **Frontend (React.js)**
   - User Interface for interacting with the application.
   - Responsible for rendering user interfaces based on state managed by the backend.
   
2. **Backend (Node.js + Express)**
   - API server that handles business logic and data access.
   - Exposes endpoints for frontend to interact with.

3. **Database (PostgreSQL)**
   - Stores all application data, including users, tasks, projects, and time logs.

4. **Authentication Service (JWT)**
   - Manages user authentication and authorization.
   - Provides endpoints for user registration, login, and token refresh.

5. **Task Management Service**
   - Handles the creation, updating, and deletion of tasks.
   - Interacts with the database to store and retrieve task data.

6. **Time Logging Service**
   - Records time spent on tasks.
   - Calculates total time logged for each project.

7. **Project Management Service**
   - Manages projects and assigns tasks to them.
   - Handles project-related data such as deadlines and budgets.

## Data Flow

1. **User Registration/Login**
   - User submits credentials (email, password).
   - Authentication service verifies credentials and issues JWT tokens.

2. **Task Creation/Update/Deletion**
   - Frontend sends task details to backend.
   - Task Management Service processes the request and updates the database.

3. **Time Logging**
   - User logs time spent on a task using the frontend.
   - Time Logging Service records the time and updates the corresponding task.

4. **Project Management**
   - Frontend sends project data to backend.
   - Project Management Service processes the request and updates the database.

## Integration Points

1. **Frontend-Backend Integration**
   - The frontend makes API requests to the backend using HTTP/HTTPS.
   - Requests are authenticated using JWT tokens.

2. **Database Access**
   - Backend services interact with the PostgreSQL database through ORM (Sequelize).

3. **Authentication Service Integration**
   - Task Management and Time Logging Services rely on the authentication service for user data.

4. **Project Management Integration**
   - Task Management Service interacts with Project Management Service to manage task assignments.
