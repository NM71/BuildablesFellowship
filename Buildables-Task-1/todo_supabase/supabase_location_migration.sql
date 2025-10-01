-- ===========================================
-- COLLABORATOR LOCATION TRACKING MIGRATION
-- ===========================================
-- Run this entire script in your Supabase SQL Editor

-- Drop existing tables if they exist with wrong column names
DROP TABLE IF EXISTS user_online_status CASCADE;
DROP TABLE IF EXISTS user_locations CASCADE;

-- Create user_locations table to store location data
CREATE TABLE user_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  location_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_online BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_online_status table to track online/offline status
CREATE TABLE user_online_status (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_location_id UUID REFERENCES user_locations(id),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_user_locations_user_id ON user_locations(user_id);
CREATE INDEX idx_user_locations_timestamp ON user_locations(location_timestamp DESC);
CREATE INDEX idx_user_online_status_online ON user_online_status(is_online);

-- ===========================================
-- ROW LEVEL SECURITY POLICIES
-- ===========================================

-- Enable RLS on both tables
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_online_status ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see locations of collaborators on tasks they're involved in
CREATE POLICY "Users can view collaborator locations" ON user_locations
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM task_collaborators tc
    WHERE tc.task_id IN (
      SELECT tc2.task_id FROM task_collaborators tc2
      WHERE tc2.user_id = auth.uid()
    )
    AND tc.user_id = user_locations.user_id
    AND tc.accepted_at IS NOT NULL
  )
  OR user_id = auth.uid() -- Users can always see their own location
);

-- Policy: Users can insert/update their own location
CREATE POLICY "Users can manage their own location" ON user_locations
FOR ALL USING (auth.uid() = user_id);

-- Policy: Users can view online status of collaborators
CREATE POLICY "Users can view collaborator online status" ON user_online_status
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM task_collaborators tc
    WHERE tc.task_id IN (
      SELECT tc2.task_id FROM task_collaborators tc2
      WHERE tc2.user_id = auth.uid()
    )
    AND tc.user_id = user_online_status.user_id
    AND tc.accepted_at IS NOT NULL
  )
  OR user_id = auth.uid() -- Users can always see their own status
);

-- Policy: Users can update their own online status
CREATE POLICY "Users can manage their own online status" ON user_online_status
FOR ALL USING (auth.uid() = user_id);

-- ===========================================
-- HELPER FUNCTIONS
-- ===========================================

-- Function to update user location and online status
CREATE OR REPLACE FUNCTION update_user_location(
  p_user_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  location_id UUID;
BEGIN
  -- Insert new location
  INSERT INTO user_locations (user_id, latitude, longitude, accuracy, is_online)
  VALUES (p_user_id, p_latitude, p_longitude, p_accuracy, true)
  RETURNING id INTO location_id;

  -- Update or insert online status
  INSERT INTO user_online_status (user_id, is_online, last_seen, last_location_id)
  VALUES (p_user_id, true, NOW(), location_id)
  ON CONFLICT (user_id)
  DO UPDATE SET
    is_online = true,
    last_seen = NOW(),
    last_location_id = location_id,
    updated_at = NOW();

  RETURN location_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all task participant locations (including owner and collaborators)
CREATE OR REPLACE FUNCTION get_task_participant_locations(p_task_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  location_timestamp TIMESTAMP WITH TIME ZONE,
  is_online BOOLEAN,
  last_seen TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  -- Get task owner location
  SELECT
    t.user_id as user_id,
    u.email,
    ul.latitude,
    ul.longitude,
    ul.accuracy,
    ul.location_timestamp,
    COALESCE(uos.is_online, false) as is_online,
    uos.last_seen
  FROM tasks t
  JOIN auth.users u ON t.user_id = u.id
  LEFT JOIN user_online_status uos ON t.user_id = uos.user_id
  LEFT JOIN user_locations ul ON uos.last_location_id = ul.id
  WHERE t.id = p_task_id

  UNION ALL

  -- Get collaborator locations
  SELECT
    tc.user_id as user_id,
    u.email,
    ul.latitude,
    ul.longitude,
    ul.accuracy,
    ul.location_timestamp,
    COALESCE(uos.is_online, false) as is_online,
    uos.last_seen
  FROM task_collaborators tc
  JOIN auth.users u ON tc.user_id = u.id
  LEFT JOIN user_online_status uos ON tc.user_id = uos.user_id
  LEFT JOIN user_locations ul ON uos.last_location_id = ul.id
  WHERE tc.task_id = p_task_id
    AND tc.accepted_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get collaborators' locations for a specific task (legacy - now includes all participants)
CREATE OR REPLACE FUNCTION get_task_collaborator_locations(p_task_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  location_timestamp TIMESTAMP WITH TIME ZONE,
  is_online BOOLEAN,
  last_seen TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM get_task_participant_locations(p_task_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark user as offline
CREATE OR REPLACE FUNCTION mark_user_offline(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_online_status
  SET is_online = false, last_seen = NOW(), updated_at = NOW()
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- REALTIME SUBSCRIPTIONS
-- ===========================================

-- Enable realtime for location updates
ALTER PUBLICATION supabase_realtime ADD TABLE user_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE user_online_status;
