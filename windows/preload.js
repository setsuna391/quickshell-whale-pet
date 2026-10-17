const { contextBridge, ipcRenderer } = require("electron");

function on(channel, cb) {
  const handler = (_event, data) => cb(data);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
}

contextBridge.exposeInMainWorld("pet", {
  bootstrap: () => ipcRenderer.invoke("bootstrap"),
  setIgnoreMouse: (ignore) => ipcRenderer.send("set-ignore-mouse", !!ignore),
  beginDrag: () => ipcRenderer.send("drag-start"),
  dragMove: () => ipcRenderer.send("drag-move"),
  endDrag: () => ipcRenderer.invoke("drag-end"),
  setModel: (name) => ipcRenderer.invoke("set-model", name),
  cycleModel: () => ipcRenderer.invoke("cycle-model"),
  getModel: () => ipcRenderer.invoke("get-model"),
  getBalances: () => ipcRenderer.invoke("get-balances"),
  refreshBalances: () => ipcRenderer.send("refresh-balances"),
  getState: () => ipcRenderer.invoke("get-state"),
  openConfig: () => ipcRenderer.invoke("open-config"),
  quit: () => ipcRenderer.send("quit"),
  onConfig: (cb) => on("config-changed", cb),
  onState: (cb) => on("state-changed", cb),
  onBalances: (cb) => on("balances", cb),
  onModel: (cb) => on("model-changed", cb),
  onSay: (cb) => on("say", cb),
});
