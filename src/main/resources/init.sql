-- ============================================================================
-- DocMind-02 Database Schema
-- Compatible with Local PostgreSQL (Docker) & Neon Serverless PostgreSQL
-- Note: Embeddings/vectors are stored remotely in Pinecone (docmind-02-vectors)
-- ============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. User Management Table (DocMind-02 Native Auth)
CREATE TABLE IF NOT EXISTS app_users (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(160) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(40) NOT NULL DEFAULT 'ROLE_USER',
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verification_token_hash VARCHAR(64),
    verification_token_expiry TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users(email);
CREATE INDEX IF NOT EXISTS idx_app_users_username ON app_users(username);

-- 3. Document Metadata Table
CREATE TABLE IF NOT EXISTS document_metadata (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    owner_id VARCHAR(36) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL,
    total_pages INT,
    total_chunks INT,
    vector_revision VARCHAR(100),
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_doc_metadata_owner ON document_metadata(owner_id);
CREATE INDEX IF NOT EXISTS idx_doc_metadata_status ON document_metadata(status);

-- 4. Document Chunks Table (BM25 Keyword Search & Passage Context)
CREATE TABLE IF NOT EXISTS docmind_chunks (
    id VARCHAR(255) PRIMARY KEY,
    owner_id VARCHAR(36) NOT NULL,
    document_id VARCHAR(36) NOT NULL,
    vector_revision VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    metadata TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS docmind_chunks_scope ON docmind_chunks(owner_id, document_id);
CREATE INDEX IF NOT EXISTS idx_docmind_chunks_owner ON docmind_chunks(owner_id);

-- ============================================================================
-- 5. Neon Auth / Better Auth Schema (for Google & GitHub OAuth)
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS neon_auth;

CREATE TABLE IF NOT EXISTS neon_auth.user (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    image TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS neon_auth.session (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES neon_auth.user(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS neon_auth.account (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES neon_auth.user(id) ON DELETE CASCADE,
    account_id TEXT NOT NULL,
    provider_id TEXT NOT NULL, -- 'google', 'github', etc.
    access_token TEXT,
    refresh_token TEXT,
    id_token TEXT,
    access_token_expires_at TIMESTAMP,
    refresh_token_expires_at TIMESTAMP,
    scope TEXT,
    password TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_provider_account UNIQUE (provider_id, account_id)
);

CREATE TABLE IF NOT EXISTS neon_auth.verification (
    id TEXT PRIMARY KEY,
    identifier TEXT NOT NULL,
    value TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
