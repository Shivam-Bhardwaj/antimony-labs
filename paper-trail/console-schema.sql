-- Antimony Labs Console Database Schema
-- Extends the existing paper-trail schema

-- Users (already exists in paper-trail schema, but extended)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    github_username VARCHAR(100),
    github_token_encrypted TEXT, -- Encrypted
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Projects - Each user can have multiple projects
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    repo_url TEXT, -- GitHub repo URL
    deployment_url TEXT, -- Live site URL
    project_type VARCHAR(50), -- 'personal', 'client', 'antimony', 'opensource'
    is_private BOOLEAN DEFAULT false,
    tech_stack JSONB, -- ["Next.js", "React", "TypeScript"]
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, slug)
);

-- Tasks - Feature requests, bugs, improvements
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    task_type VARCHAR(50), -- 'feature', 'bug', 'refactor', 'optimization'
    priority VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'in_progress', 'review', 'completed', 'failed'

    -- LLM Processing
    assigned_llm VARCHAR(50), -- 'claude-hpc', 'codex-hpc', 'claude-rpi5', 'codex-rpi5'
    llm_session_id UUID,
    estimated_time_minutes INT,

    -- Git Integration
    branch_name VARCHAR(100),
    commit_hash VARCHAR(100),
    pr_url TEXT,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    metadata JSONB -- Additional context, files changed, etc.
);

-- Task Activity Log
CREATE TABLE IF NOT EXISTS task_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    llm_name VARCHAR(50),
    activity_type VARCHAR(50), -- 'planning', 'coding', 'testing', 'committing'
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- User Contributions (for leaderboard)
CREATE TABLE IF NOT EXISTS contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    project_id UUID REFERENCES projects(id),
    contribution_type VARCHAR(50), -- 'code', 'idea', 'review', 'documentation'
    points INT DEFAULT 0,
    description TEXT,
    proof_url TEXT, -- Link to commit, PR, etc.
    created_at TIMESTAMP DEFAULT NOW()
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES tasks(id),
    title VARCHAR(255),
    message TEXT,
    notification_type VARCHAR(50), -- 'task_completed', 'error', 'deployment_success'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- API Keys for external integrations
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    service_name VARCHAR(100), -- 'github', 'vercel', 'cloudflare'
    key_encrypted TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_projects_user ON projects(user_id);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_assigned_llm ON tasks(assigned_llm);
CREATE INDEX idx_contributions_user ON contributions(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- Initial data: Shivam's account
INSERT INTO users (username, email, github_username) VALUES
('shivam', 'shivam@shivambhardwaj.com', 'shivam-bhardwaj')
ON CONFLICT (username) DO NOTHING;

-- Shivam's projects
INSERT INTO projects (user_id, name, slug, description, repo_url, deployment_url, project_type, is_private) VALUES
(
    (SELECT id FROM users WHERE username = 'shivam'),
    'AutoCrate',
    'autocrate',
    'NX CAD crate design generator with 3D visualization',
    'https://github.com/Shivam-Bhardwaj/AutoCrate',
    'https://autocrate.vercel.app',
    'client',
    true
),
(
    (SELECT id FROM users WHERE username = 'shivam'),
    'Personal Website',
    'shivambhardwaj-com',
    'Personal portfolio and blog',
    'https://github.com/shivam-bhardwaj/shivambhardwaj.com',
    'https://shivambhardwaj.com',
    'personal',
    false
),
(
    (SELECT id FROM users WHERE username = 'shivam'),
    'Antimony Labs',
    'antimony-labs',
    'Collaborative knowledge platform with LLM coordination',
    'https://github.com/shivam-bhardwaj/antimony-labs',
    'https://antimony-labs.org',
    'antimony',
    false
)
ON CONFLICT (user_id, slug) DO NOTHING;
