-- Remove anonymous direct invocation of security-definer membership helper.
revoke execute on function public.has_org_role(uuid,public.member_role[]) from anon;
