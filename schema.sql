CREATE TABLE users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text NOT NULL,
    display_name text,
    timezone text DEFAULT 'UTC',
    notification_preferences jsonb DEFAULT '{"email": true, "push": false}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE personal_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    hebrew_date date NOT NULL,
    gregorian_date date NOT NULL,
    event_type text NOT NULL CHECK (event_type IN ('holiday', 'fast', 'personal', 'reminder')),
    is_recurring boolean DEFAULT false,
    recurrence_rule text,
    notification_time timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE community_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    submitted_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text NOT NULL,
    hebrew_date date NOT NULL,
    gregorian_date date NOT NULL,
    event_type text NOT NULL CHECK (event_type IN ('community', 'historical', 'custom')),
    source_citation text,
    votes integer DEFAULT 0,
    approved boolean DEFAULT false,
    reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE user_subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    community_event_id uuid NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
    vote_status integer DEFAULT 0 CHECK (vote_status IN (-1, 0, 1)),
    is_bookmarked boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, community_event_id)
);

CREATE INDEX idx_personal_events_user_id ON personal_events(user_id);
CREATE INDEX idx_personal_events_gregorian_date ON personal_events(gregorian_date);
CREATE INDEX idx_personal_events_hebrew_date ON personal_events(hebrew_date);
CREATE INDEX idx_community_events_submitted_by ON community_events(submitted_by);
CREATE INDEX idx_community_events_approved ON community_events(approved);
CREATE INDEX idx_community_events_gregorian_date ON community_events(gregorian_date);
CREATE INDEX idx_community_events_hebrew_date ON community_events(hebrew_date);
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_community_event_id ON user_subscriptions(community_event_id);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Personal events are private to each user"
    ON personal_events FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view approved community events"
    ON community_events FOR SELECT
    USING (approved = true OR auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND auth.jwt() ->> 'email' LIKE '%@jcaladmin.com'));

CREATE POLICY "Authenticated users can insert community events"
    ON community_events FOR INSERT
    WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "Users can update their own community events"
    ON community_events FOR UPDATE
    USING (auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND auth.jwt() ->> 'email' LIKE '%@jcaladmin.com'));

CREATE POLICY "Users can manage their own subscriptions"
    ON user_subscriptions FOR ALL
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_personal_events_updated_at BEFORE UPDATE ON personal_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_community_events_updated_at BEFORE UPDATE ON community_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_subscriptions_updated_at BEFORE UPDATE ON user_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();