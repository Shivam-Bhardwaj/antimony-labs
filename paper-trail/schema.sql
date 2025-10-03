-- Paper-Trail Database Schema
-- Persistent knowledge system that survives restarts

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (invite-only)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    invite_code VARCHAR(64) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    last_active TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Ideas table - User submissions
CREATE TABLE ideas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50), -- STEM, non-STEM, etc.
    status VARCHAR(50) DEFAULT 'submitted', -- submitted, refining, approved, rejected
    uniqueness_score FLOAT DEFAULT 0.0,
    quality_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- PRDs (Product Requirement Documents) - Generated from ideas
CREATE TABLE prds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idea_id UUID REFERENCES ideas(id) ON DELETE CASCADE,
    version INTEGER DEFAULT 1,
    content TEXT NOT NULL,
    generated_by VARCHAR(50), -- claude-rpi5, claude-hpc, etc.
    created_at TIMESTAMP DEFAULT NOW(),
    embedding_id VARCHAR(255), -- Reference to vector in Qdrant
    metadata JSONB DEFAULT '{}'::jsonb
);

-- NFT Tokens - Minted for approved ideas
CREATE TABLE nft_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idea_id UUID REFERENCES ideas(id) ON DELETE CASCADE,
    token_id VARCHAR(255) UNIQUE NOT NULL,
    blockchain VARCHAR(50) DEFAULT 'ethereum',
    contract_address VARCHAR(255),
    owner_id UUID REFERENCES users(id),
    minted_at TIMESTAMP DEFAULT NOW(),
    transaction_hash VARCHAR(255),
    ipfs_hash VARCHAR(255), -- Metadata stored on IPFS
    current_value DECIMAL(20, 8),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Contributions - Code, CAD, docs, etc.
CREATE TABLE contributions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idea_id UUID REFERENCES ideas(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    contribution_type VARCHAR(50), -- code, cad, documentation, refinement
    description TEXT,
    git_repo_url TEXT,
    git_commit_hash VARCHAR(255),
    file_paths TEXT[], -- Array of files in this contribution
    ipfs_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    crypto_signature TEXT, -- Cryptographic proof
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Contribution Graph - Relationships between contributions
CREATE TABLE contribution_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_contribution_id UUID REFERENCES contributions(id),
    child_contribution_id UUID REFERENCES contributions(id),
    relationship_type VARCHAR(50), -- builds_on, refines, references, conflicts
    created_at TIMESTAMP DEFAULT NOW()
);

-- LLM Sessions - Track LLM interactions
CREATE TABLE llm_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_key VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id),
    idea_id UUID REFERENCES ideas(id),
    llm_instances JSONB, -- Which LLMs are involved: [claude-rpi5, codex-hpc, etc.]
    conversation_history JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Paper-Trail Brain - Learned patterns and knowledge
CREATE TABLE brain_learnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pattern_type VARCHAR(100), -- code_pattern, design_pattern, user_preference
    pattern_data JSONB NOT NULL,
    confidence_score FLOAT DEFAULT 0.0,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used TIMESTAMP DEFAULT NOW(),
    embedding_id VARCHAR(255) -- Vector embedding for semantic search
);

-- Cryptographic Ledger - Immutable audit trail
CREATE TABLE crypto_ledger (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50), -- idea, contribution, nft, etc.
    entity_id UUID NOT NULL,
    action VARCHAR(50), -- created, modified, minted, transferred
    merkle_root VARCHAR(255),
    previous_hash VARCHAR(255),
    current_hash VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW(),
    signed_by UUID REFERENCES users(id),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for performance
CREATE INDEX idx_ideas_user ON ideas(user_id);
CREATE INDEX idx_ideas_status ON ideas(status);
CREATE INDEX idx_ideas_created ON ideas(created_at DESC);
CREATE INDEX idx_prds_idea ON prds(idea_id);
CREATE INDEX idx_nft_idea ON nft_tokens(idea_id);
CREATE INDEX idx_nft_owner ON nft_tokens(owner_id);
CREATE INDEX idx_contributions_idea ON contributions(idea_id);
CREATE INDEX idx_contributions_user ON contributions(user_id);
CREATE INDEX idx_contributions_type ON contributions(contribution_type);
CREATE INDEX idx_llm_sessions_user ON llm_sessions(user_id);
CREATE INDEX idx_llm_sessions_active ON llm_sessions(is_active);
CREATE INDEX idx_crypto_ledger_entity ON crypto_ledger(entity_type, entity_id);
CREATE INDEX idx_brain_pattern_type ON brain_learnings(pattern_type);

-- Create Gitea database for Gitea service
CREATE DATABASE gitea;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE gitea TO antimony;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO antimony;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO antimony;
