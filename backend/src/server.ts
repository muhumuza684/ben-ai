import 'dotenv/config';
import http from 'node:http';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

const port = Number(process.env.PORT ?? 8787);
const groqKey = process.env.GROQ_API_KEY ?? '';
const groqModel = process.env.GROQ_MODEL ?? 'llama-3.1-8b-instant';
const supabase: SupabaseClient | null = process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null;

const send = (res: http.ServerResponse, status: number, body: unknown) => {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type' });
  res.end(JSON.stringify(body));
};

const readJson = (req: http.IncomingMessage): Promise<Record<string, any>> => new Promise((resolve, reject) => {
  let data = '';
  req.on('data', chunk => { data += chunk; });
  req.on('end', () => { try { resolve(data ? JSON.parse(data) : {}); } catch (error) { reject(error); } });
  req.on('error', reject);
});

async function chat(body: Record<string, any>) {
  if (!groqKey) throw new Error('GROQ_API_KEY is not configured on the server');
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${groqKey}` },
    body: JSON.stringify({ model: groqModel, messages: body.messages, max_tokens: body.max_tokens ?? 180, temperature: body.temperature ?? 0.75 }),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`Groq request failed: ${response.status}`);
  return result;
}

async function saveMessage(body: Record<string, any>, result: any) {
  if (!supabase || !body.userId || !body.contactId) return;
  await supabase.from('messages').insert({ user_id: body.userId, contact_id: body.contactId, role: 'assistant', content: result.choices?.[0]?.message?.content ?? '' });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type' }); res.end(); return; }
  try {
    if (req.url === '/health' && req.method === 'GET') return send(res, 200, { ok: true, service: 'ben-ai-backend', persistence: Boolean(supabase) });
    if (req.url === '/v1/chat' && req.method === 'POST') {
      const body = await readJson(req);
      if (!Array.isArray(body.messages)) return send(res, 400, { error: 'messages must be an array' });
      const result = await chat(body);
      await saveMessage(body, result);
      return send(res, 200, result);
    }
    if (req.url === '/v1/reminders' && req.method === 'POST') {
      const body = await readJson(req);
      if (!body.userId || !body.contactId || !body.scheduledAt) return send(res, 400, { error: 'userId, contactId, and scheduledAt are required' });
      if (!supabase) return send(res, 201, { id: `local-${Date.now()}`, ...body, status: 'scheduled' });
      const { data, error } = await supabase.from('reminders').insert({ ...body, status: 'scheduled' }).select().single();
      if (error) return send(res, 500, { error: error.message });
      return send(res, 201, data);
    }
    if (req.url === '/v1/reminders' && req.method === 'GET') {
      if (!supabase) return send(res, 200, []);
      const { data, error } = await supabase.from('reminders').select('*').order('scheduled_at', { ascending: true });
      if (error) return send(res, 500, { error: error.message });
      return send(res, 200, data ?? []);
    }
    send(res, 404, { error: 'Not found' });
  } catch (error) {
    send(res, 500, { error: error instanceof Error ? error.message : 'Server error' });
  }
});

server.listen(port, '0.0.0.0', () => console.log(`Ben AI backend listening on ${port}`));
