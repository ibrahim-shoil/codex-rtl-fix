import WebSocket from "ws";

async function connectCdpSocket(webSocketDebuggerUrl, port) {
  const socket = new WebSocket(webSocketDebuggerUrl, {
    origin: `http://127.0.0.1:${port}`
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  let nextId = 1;
  const pending = new Map();

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (!message.id) return;
    const handler = pending.get(message.id);
    if (!handler) return;
    pending.delete(message.id);
    if (message.error) {
      handler.reject(new Error(`${message.error.code}: ${message.error.message}`));
    } else {
      handler.resolve(message.result);
    }
  });

  socket.addEventListener("close", () => {
    for (const handler of pending.values()) {
      handler.reject(new Error("CDP browser connection closed."));
    }
    pending.clear();
  });

  return {
    socket,
    request(method, params = {}, sessionId) {
      const id = nextId++;
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          pending.delete(id);
          reject(new Error(`CDP request timed out: ${method}`));
        }, 5000);
        pending.set(id, {
          resolve(value) {
            clearTimeout(timeout);
            resolve(value);
          },
          reject(error) {
            clearTimeout(timeout);
            reject(error);
          }
        });
        socket.send(JSON.stringify({
          id,
          method,
          params,
          ...(sessionId ? { sessionId } : {})
        }));
      });
    },
    close() {
      socket.close();
    }
  };
}

export async function connectBrowserCdp(port) {
  const version = await fetch(`http://127.0.0.1:${port}/json/version`, {
    signal: AbortSignal.timeout(2000)
  }).then((response) => {
    if (!response.ok) throw new Error(`CDP returned ${response.status}`);
    return response.json();
  });
  return connectCdpSocket(version.webSocketDebuggerUrl, port);
}

export async function connectPageCdp(webSocketDebuggerUrl, port) {
  return connectCdpSocket(webSocketDebuggerUrl, port);
}

export async function attachToPage(client, targetId) {
  const { sessionId } = await client.request("Target.attachToTarget", {
    targetId,
    flatten: true
  });
  return sessionId;
}
