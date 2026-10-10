'use server';
import { redirect } from 'next/navigation';
import { createClient } from '../../lib/supabase/server';
export async function signIn(formData: FormData) {
  const email = String(formData.get('email') || '').trim();
  const password = String(formData.get('password') || '');
  if (!email || !password) redirect('/login?error=Enter%20email%20and%20password');
  const supabase = await createClient();
  const {error} = await supabase.auth.signInWithPassword({email,password});
  if (error) redirect('/login?error=Sign-in%20failed.%20Check%20credentials%20or%20contact%20the%20owner');
  redirect('/dashboard');
}
