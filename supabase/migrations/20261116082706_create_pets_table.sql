CREATE TABLE public.pets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_id UUID NOT NULL
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,
    breed TEXT,
    age INTEGER,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can view their pets"
ON public.pets
FOR SELECT
TO authenticated
USING (auth.uid() = owner_id);