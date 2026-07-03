import { useCallback, useEffect, useRef, useState } from 'react';
import { chatApi } from '../../api/chat';
import { myId } from '../../api/supabase';
import type { ChatConversation, ChatMessage } from '../../api/types';
import { Spinner, Empty } from '../../components/ui';

function timeLabel(iso: string): string {
  return new Date(iso).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function MessagesPage() {
  const [me, setMe] = useState('');
  const [convos, setConvos] = useState<ChatConversation[] | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [thread, setThread] = useState<ChatMessage[] | null>(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const activeIdRef = useRef<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => { myId().then(setMe); }, []);

  const loadConvos = useCallback(() => {
    chatApi.conversations().then(setConvos).catch((e) => setError(e.message));
  }, []);

  const loadThread = useCallback((id: string) => {
    chatApi.messages(id).then(setThread).catch((e) => setError(e.message));
  }, []);

  useEffect(loadConvos, [loadConvos]);

  const openConversation = useCallback((id: string) => {
    setActiveId(id);
    activeIdRef.current = id;
    setThread(null);
    loadThread(id);
    chatApi.markRead(id).then(loadConvos).catch(() => undefined);
  }, [loadThread, loadConvos]);

  // Realtime: refresh the open thread + list on any new message.
  useEffect(() => {
    const channel = chatApi.subscribe(() => {
      loadConvos();
      const open = activeIdRef.current;
      if (open) {
        loadThread(open);
        chatApi.markRead(open).catch(() => undefined);
      }
    });
    return () => { channel.unsubscribe(); };
  }, [loadConvos, loadThread]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [thread]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = draft.trim();
    if (!body || !activeId) return;
    setSending(true);
    setError('');
    try {
      await chatApi.send(activeId, body);
      setDraft('');
      loadThread(activeId);
      loadConvos();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send message.');
    } finally {
      setSending(false);
    }
  }

  if (error && !convos) return <div className="error-text">{error}</div>;
  if (!convos) return <Spinner />;

  const active = convos.find((c) => c.id === activeId) ?? null;

  return (
    <div className="chat-layout">
      <aside className="card chat-list">
        {convos.length === 0 ? (
          <Empty>No conversations yet.</Empty>
        ) : (
          convos.map((c) => (
            <button
              key={c.id}
              type="button"
              className={`chat-list-item${c.id === activeId ? ' active' : ''}`}
              onClick={() => openConversation(c.id)}
            >
              <div className="between">
                <span className="chat-name">{c.patient?.full_name ?? 'Patient'}</span>
                {c.unread > 0 && <span className="chat-unread-dot" aria-label={`${c.unread} unread`} />}
              </div>
              <div className="chat-preview muted">{c.last_message ?? 'No messages yet'}</div>
            </button>
          ))
        )}
      </aside>

      <section className="card chat-thread">
        {!active ? (
          <Empty>Select a conversation to start messaging.</Empty>
        ) : (
          <>
            <header className="chat-thread-head between">
              <div>
                <strong>{active.patient?.full_name ?? 'Patient'}</strong>
                {active.patient?.cnic && <div className="muted" style={{ fontSize: 12 }}>{active.patient.cnic}</div>}
              </div>
            </header>

            <div className="chat-messages">
              {!thread ? (
                <Spinner />
              ) : thread.length === 0 ? (
                <Empty>No messages yet. Say hello.</Empty>
              ) : (
                thread.map((m) => {
                  const mine = m.sender_id === me;
                  return (
                    <div key={m.id} className={`chat-bubble-row${mine ? ' mine' : ''}`}>
                      <div className={`chat-bubble${mine ? ' mine' : ''}`}>
                        <div>{m.body}</div>
                        <div className="chat-time">{timeLabel(m.created_at)}</div>
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={endRef} />
            </div>

            {error && <div className="error-text">{error}</div>}
            <form className="chat-compose" onSubmit={send}>
              <input
                className="input"
                placeholder="Type a message…"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                disabled={sending}
              />
              <button className="btn btn-primary" type="submit" disabled={sending || !draft.trim()}>
                Send
              </button>
            </form>
          </>
        )}
      </section>
    </div>
  );
}
