import type { RealtimeChannel } from '@supabase/supabase-js';
import { supabase, myId } from './supabase';
import type { ChatConversation, ChatMessage } from './types';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Q = any;
const nowIso = () => new Date().toISOString();

async function rows<T>(builder: Q): Promise<T[]> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}

export const chatApi = {
  async conversations(): Promise<ChatConversation[]> {
    const me = await myId();
    const convos = await rows<Q>(
      supabase.from('conversations').select('*, patient:profiles!patient_id(id, full_name, card_number)')
        .eq('doctor_id', me).order('last_message_at', { ascending: false, nullsFirst: false }),
    );
    if (convos.length === 0) return [];
    const unread = await rows<Q>(
      supabase.from('messages').select('conversation_id')
        .in('conversation_id', convos.map((c) => c.id)).neq('sender_id', me).is('read_at', null),
    );
    const counts: Record<string, number> = {};
    unread.forEach((m) => (counts[m.conversation_id] = (counts[m.conversation_id] ?? 0) + 1));
    return convos.map((c) => ({ ...c, unread: counts[c.id] ?? 0 })) as ChatConversation[];
  },

  messages(conversationId: string): Promise<ChatMessage[]> {
    return rows<ChatMessage>(
      supabase.from('messages').select('*').eq('conversation_id', conversationId)
        .order('created_at', { ascending: true }),
    );
  },

  async send(conversationId: string, body: string): Promise<ChatMessage> {
    const { data, error } = await supabase.from('messages')
      .insert({ conversation_id: conversationId, sender_id: await myId(), body })
      .select().single();
    if (error) throw new Error(error.message);
    return data as ChatMessage;
  },

  async markRead(conversationId: string) {
    const me = await myId();
    const { error } = await supabase.from('messages').update({ read_at: nowIso() })
      .eq('conversation_id', conversationId).neq('sender_id', me).is('read_at', null);
    if (error) throw new Error(error.message);
  },

  subscribe(onChange: () => void): RealtimeChannel {
    return supabase.channel('staff:messages')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, () => onChange())
      .subscribe();
  },
};
