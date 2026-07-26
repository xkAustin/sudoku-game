-- Read-only verification for the deployed Data API leaderboard schema.
-- Run with:
--   supabase db query --linked \
--     --file backend/supabase/tests/verify_data_api_scores.sql --output table

select jsonb_pretty(jsonb_build_object(
	'tables',
	(
		select coalesce(jsonb_agg(to_jsonb(tables) order by tables.table_name), '[]'::jsonb)
		from (
			select
				c.relname as table_name,
				c.relrowsecurity as rls_enabled,
				c.relforcerowsecurity as rls_forced,
				has_table_privilege('anon', format('public.%I', c.relname), 'select') as anon_can_select,
				has_table_privilege('anon', format('public.%I', c.relname), 'insert') as anon_can_insert,
				has_table_privilege('anon', format('public.%I', c.relname), 'update') as anon_can_update,
				has_table_privilege('anon', format('public.%I', c.relname), 'delete') as anon_can_delete
			from pg_class c
			join pg_namespace n on n.oid = c.relnamespace
			where n.nspname = 'public'
				and c.relname in ('scores', 'score_submission_guards')
				and c.relkind = 'r'
		) tables
	),
	'table_security',
	(
		select to_jsonb(security)
		from (
			select
				c.relrowsecurity as rls_enabled,
				c.relforcerowsecurity as rls_forced,
				has_table_privilege('anon', 'public.scores', 'select') as anon_can_select,
				has_table_privilege('anon', 'public.scores', 'insert') as anon_can_insert,
				has_table_privilege('anon', 'public.scores', 'update') as anon_can_update,
				has_table_privilege('anon', 'public.scores', 'delete') as anon_can_delete
			from pg_class c
			join pg_namespace n on n.oid = c.relnamespace
			where n.nspname = 'public' and c.relname = 'scores'
		) security
	),
	'columns',
	(
		select jsonb_agg(to_jsonb(columns) order by columns.ordinal_position)
		from (
			select ordinal_position, column_name, data_type, is_nullable
			from information_schema.columns
			where table_schema = 'public' and table_name = 'scores'
		) columns
	),
	'indexes',
	(
		select jsonb_agg(to_jsonb(indexes) order by indexes.indexname)
		from (
			select indexname, indexdef
			from pg_indexes
			where schemaname = 'public'
				and tablename in ('scores', 'score_submission_guards')
		) indexes
	),
	'functions',
	(
		select jsonb_agg(to_jsonb(functions) order by functions.proname, functions.arguments)
		from (
			select
				p.proname,
				pg_get_function_identity_arguments(p.oid) as arguments,
				p.prosecdef as security_definer,
				p.proconfig as configuration
			from pg_proc p
			join pg_namespace n on n.oid = p.pronamespace
			where n.nspname = 'public'
				and p.proname in (
					'normalize_player_name',
					'calculate_ranked_score',
					'submit_score',
					'get_leaderboard'
				)
		) functions
	),
	'client_function_privileges',
	(
		select coalesce(jsonb_agg(to_jsonb(privileges) order by privileges.routine_name, privileges.grantee), '[]'::jsonb)
		from (
			select grantee, routine_name, privilege_type
			from information_schema.routine_privileges
			where specific_schema = 'public'
				and routine_name in (
					'normalize_player_name',
					'calculate_ranked_score',
					'submit_score',
					'get_leaderboard'
				)
				and grantee in ('anon', 'authenticated', 'PUBLIC')
		) privileges
	),
	'policies',
	(
		select coalesce(jsonb_agg(to_jsonb(policies) order by policies.tablename, policies.policyname), '[]'::jsonb)
		from (
			select tablename, policyname, permissive, roles, cmd, qual, with_check
			from pg_policies
			where schemaname = 'public'
				and tablename in ('scores', 'score_submission_guards')
		) policies
	),
	'triggers',
	(
		select coalesce(jsonb_agg(to_jsonb(triggers) order by triggers.event_object_table, triggers.trigger_name), '[]'::jsonb)
		from (
			select
				event_object_table,
				trigger_name,
				event_manipulation,
				action_timing,
				action_statement
			from information_schema.triggers
			where trigger_schema = 'public'
				and event_object_table in ('scores', 'score_submission_guards')
		) triggers
	)
)) as verification;
