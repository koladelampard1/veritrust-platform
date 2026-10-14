-- Remove temporary diagnostic function used during development migration debugging.
drop function if exists public.veritrust_probe_rate();
