import { supabase } from './supabase';
import type { AppNotification } from './types';

async function currentUserId(): Promise<string | null> {
  return (await supabase.auth.getUser()).data.user?.id ?? null;
}

export const notificationsApi = {
  /** Recent notifications for the current admin, newest first. */
  async list(limit = 30): Promise<AppNotification[]> {
    const uid = await currentUserId();
    if (!uid) return [];
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('recipient_id', uid)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return (data ?? []) as AppNotification[];
  },

  /** Count of unread notifications for the current admin. */
  async unreadCount(): Promise<number> {
    const uid = await currentUserId();
    if (!uid) return 0;
    const { count, error } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('recipient_id', uid)
      .eq('is_read', false);
    if (error) throw new Error(error.message);
    return count ?? 0;
  },

  async markRead(id: string): Promise<void> {
    const { error } = await supabase.from('notifications').update({ is_read: true }).eq('id', id);
    if (error) throw new Error(error.message);
  },

  async markAllRead(): Promise<void> {
    const uid = await currentUserId();
    if (!uid) return;
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('recipient_id', uid)
      .eq('is_read', false);
    if (error) throw new Error(error.message);
  },
};
