/**
 * The WebSocket close code the server uses when it refuses a socket and shows
 * it out. The close reason is the refusal, such as "unknown_seat", so a client
 * that cannot read the last message before the close (Godot's native
 * WebSocketPeer) still learns why.
 */
export const REFUSAL_CLOSE_CODE = 4000;
