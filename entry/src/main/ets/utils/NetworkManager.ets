import { webSocket } from '@kit.NetworkKit';

export interface MessageData {
  type: string;
  roomId?: string;
  playerId?: string;
  seat?: number;
  players?: Player[];
  message?: string;
  ready?: boolean;
}

export interface Player {
  seat: number;
  nickname: string;
  ready: boolean;
  online: boolean;
}

export interface SendData {
  type: string;
  playerName?: string;
  gameMode?: string;
  maxPlayers?: number;
  roomId?: string;
  ready?: boolean;
  action?: string;
  tile?: number;
}

export class NetworkManager {
  private ws: webSocket.WebSocket | null = null;
  private serverUrl: string = 'ws://192.168.1.100:8080/ws/game';
  private messageHandlers: Map<string, Array<(data: MessageData) => void>> = new Map();
  private isConnected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;

  connect(): Promise<boolean> {
    return new Promise((resolve: (value: boolean) => void, reject: (reason: Error) => void) => {
      try {
        if (this.ws) {
          this.disconnect();
        }

        const socket = webSocket.createWebSocket();
        this.ws = socket;
        
        socket.on('open', () => {
          console.info('WebSocket connected');
          this.isConnected = true;
          this.reconnectAttempts = 0;
          resolve(true);
        });

        socket.on('message', (msgErr: Error, data: string | ArrayBuffer) => {
          if (msgErr) {
            console.error('Message error:', msgErr);
            return;
          }
          this.handleMessage(data);
        });

        socket.on('close', () => {
          console.info('WebSocket closed');
          this.isConnected = false;
          this.attemptReconnect();
        });

        socket.on('error', (error: Error) => {
          console.error('WebSocket error:', error);
          this.isConnected = false;
          reject(error);
        });

        socket.connect(this.serverUrl);
      } catch (error) {
        console.error('Connect error:', error);
        reject(error as Error);
      }
    });
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.info(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
      setTimeout(() => {
        this.connect().catch(() => {});
      }, 3000);
    }
  }

  disconnect(): void {
    if (this.ws) {
      try {
        this.ws.close();
      } catch (e) {
        console.error('Close error:', e);
      }
      this.ws = null;
      this.isConnected = false;
    }
  }

  send(type: string, data: SendData): void {
    if (this.ws && this.isConnected) {
      const messageObj: Record<string, Object> = {};
      messageObj['type'] = type;
      if (data.playerName !== undefined) messageObj['playerName'] = data.playerName;
      if (data.gameMode !== undefined) messageObj['gameMode'] = data.gameMode;
      if (data.maxPlayers !== undefined) messageObj['maxPlayers'] = data.maxPlayers;
      if (data.roomId !== undefined) messageObj['roomId'] = data.roomId;
      if (data.ready !== undefined) messageObj['ready'] = data.ready;
      if (data.action !== undefined) messageObj['action'] = data.action;
      if (data.tile !== undefined) messageObj['tile'] = data.tile;
      const message = JSON.stringify(messageObj);
      try {
        this.ws.send(message);
      } catch (e) {
        console.error('Send error:', e);
      }
    } else {
      console.warn('WebSocket not connected');
    }
  }

  on(messageType: string, handler: (data: MessageData) => void): void {
    if (!this.messageHandlers.has(messageType)) {
      this.messageHandlers.set(messageType, []);
    }
    const handlers = this.messageHandlers.get(messageType);
    if (handlers) {
      handlers.push(handler);
    }
  }

  off(messageType: string, handler: (data: MessageData) => void): void {
    const handlers = this.messageHandlers.get(messageType);
    if (handlers) {
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  clearHandlers(): void {
    this.messageHandlers.clear();
  }

  private handleMessage(data: string | ArrayBuffer): void {
    try {
      const message: MessageData = JSON.parse(data as string) as MessageData;
      console.info('Received message:', message.type);
      
      const handlers = this.messageHandlers.get(message.type || '');
      if (handlers) {
        handlers.forEach(handler => handler(message));
      }
    } catch (error) {
      console.error('Parse message error:', error);
    }
  }

  get connectionStatus(): boolean {
    return this.isConnected;
  }

  setServerUrl(url: string): void {
    this.serverUrl = url;
  }
}

export const networkManager = new NetworkManager();
