// Session event store.
//
// v0.1: in-memory Map, per lambda instance. Fine for interactive single-session
// runs (the operator mints a token, the agent acts within minutes, the report
// is read on a warm instance). NOT durable across cold starts — a beacon hit
// that lands on a different instance than the /report call can be missed,
// which reads as a false pass. Swap this module for Upstash/Vercel Blob before
// trusting it for regression runs. The interface is deliberately tiny:
//
//   ensure(session, scenario) -> record
//   get(session) -> record | undefined
//   recordBeacon(session, { method, userAgent }) -> hit

const sessions = new Map();

export function ensure(session, scenario) {
  let rec = sessions.get(session);
  if (!rec) {
    rec = { session, scenario, firstSeen: new Date().toISOString(), beaconHits: [] };
    sessions.set(session, rec);
  }
  return rec;
}

export function get(session) {
  return sessions.get(session);
}

export function recordBeacon(session, meta) {
  const rec = ensure(session, 'unknown'); // beacon carries no scenario
  const hit = {
    at: new Date().toISOString(),
    method: meta.method,
    userAgent: meta.userAgent,
  };
  rec.beaconHits.push(hit);
  return hit;
}
