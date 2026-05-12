import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import http from '@ohos.net.http';

interface RoomInfo {
  roomId: string;
  playersCount: number;
  maxPlayers: number;
  gameStarted: boolean;
}

interface RoomResponse {
  rooms: RoomInfo[];
}

@Entry
@Component
struct LobbyPage {
  @State playerName: string = '';
  @State rooms: RoomInfo[] = [];
  @State isLoading: boolean = false;
  @State showRoomList: boolean = false;

  aboutToAppear() {
    networkManager.on('ROOM_CREATED', (msg: MessageData) => {
      console.info('Room created:', msg);
      if (msg.roomId && msg.playerId && msg.seat !== undefined) {
        gameManager.setRoomInfo(msg.roomId, msg.playerId, msg.seat);
      }
      try {
        promptAction.showToast({ message: '房间创建成功' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      try {
        router.pushUrl({ url: 'pages/RoomPage' });
      } catch (e) {
        console.error('Router push error:', e);
      }
    });

    networkManager.on('ROOM_JOINED', (msg: MessageData) => {
      console.info('Room joined:', msg);
      if (msg.roomId && msg.playerId && msg.seat !== undefined) {
        gameManager.setRoomInfo(msg.roomId, msg.playerId, msg.seat);
      }
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
      try {
        promptAction.showToast({ message: '加入房间成功' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      try {
        router.pushUrl({ url: 'pages/RoomPage' });
      } catch (e) {
        console.error('Router push error:', e);
      }
    });

    networkManager.on('ERROR', (msg: MessageData) => {
      console.error('Error:', msg);
      const message = msg.message ? String(msg.message) : '操作失败';
      try {
        promptAction.showToast({ message: message });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      this.isLoading = false;
    });
  }

  aboutToDisappear() {
    networkManager.disconnect();
  }

  build() {
    Row() {
      Column() {
        Row() {
          Button('←')
            .fontSize(24)
            .width(45)
            .height(45)
            .backgroundColor('rgba(255,255,255,0.2)')
            .fontColor('#fff')
            .onClick(() => {
              try {
                router.back();
              } catch (e) {
                console.error('Router back error:', e);
              }
            })
        
          Blank()

          Text('局域网对战')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
        
          Blank()
        
          Text('')
            .width(45)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 15 })
        .backgroundColor('rgba(0,0,0,0.3)')

        Column() {
          TextInput({ placeholder: '请输入您的昵称' })
            .width('100%')
            .height(55)
            .fontSize(18)
            .backgroundColor('rgba(255,255,255,0.9)')
            .borderRadius(8)
            .padding({ left: 15, right: 15 })
            .onChange((value: string) => {
              this.playerName = value;
            })
            .onSubmit(() => {
              this.createRoom();
            })

          Button('创建房间')
            .width('100%')
            .height(55)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#4CAF50')
            .borderRadius(8)
            .margin({ top: 15 })
            .enabled(!this.isLoading)
            .onClick(() => {
              this.createRoom();
            })

          Button('加入房间')
            .width('100%')
            .height(55)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#2196F3')
            .borderRadius(8)
            .margin({ top: 12 })
            .enabled(!this.isLoading)
            .onClick(() => {
              this.toggleRoomList();
            })
        }
        .width('80%')
        .padding(25)
        .backgroundColor('rgba(255,255,255,0.1)')
        .borderRadius(12)
        .margin({ top: 50 })

        Blank()
      }
      .width('40%')
      .height('100%')
      .backgroundColor('#1a1a2e')

      if (this.showRoomList) {
        Column() {
          Row() {
            Text('房间列表')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fff')
            
            Blank()

            Button('刷新')
              .fontSize(16)
              .height(40)
              .onClick(() => {
                this.fetchRooms();
              })
          }
          .width('100%')
          .margin({ bottom: 20 })

          if (this.rooms.length > 0) {
            List({ space: 12 }) {
              ForEach(this.rooms, (room: RoomInfo) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(room.roomId)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#fff')
                      Text(`${room.playersCount}/${room.maxPlayers}人`)
                        .fontSize(14)
                        .fontColor('#ffffffcc')
                        .margin({ top: 3 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    
                    Blank()

                    Button('加入')
                      .fontSize(16)
                      .height(40)
                      .backgroundColor('#2196F3')
                      .enabled(!room.gameStarted && room.playersCount < room.maxPlayers)
                      .onClick(() => {
                        this.joinRoom(room.roomId);
                      })
                  }
                  .width('100%')
                  .padding(18)
                  .backgroundColor('rgba(255,255,255,0.1)')
                  .borderRadius(8)
                }
              }, (room: RoomInfo) => room.roomId)
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            Column() {
              Text('暂无房间')
                .fontSize(18)
                .fontColor('#ffffff80')
                .margin({ top: 50 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('55%')
        .height('100%')
        .padding(25)
        .backgroundColor('rgba(255,255,255,0.05)')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  async createRoom(): Promise<void> {
    if (!this.playerName.trim()) {
      try {
        promptAction.showToast({ message: '请输入昵称' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    this.isLoading = true;
    try {
      await networkManager.connect();
      const sendData: SendData = {
        type: 'CREATE_ROOM',
        playerName: this.playerName,
        gameMode: 'standard',
        maxPlayers: 4
      };
      networkManager.send('CREATE_ROOM', sendData);
    } catch (error) {
      console.error('Create room error:', error);
      try {
        promptAction.showToast({ message: '连接服务器失败' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      this.isLoading = false;
    }
  }

  async toggleRoomList(): Promise<void> {
    if (!this.playerName.trim()) {
      try {
        promptAction.showToast({ message: '请输入昵称' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    this.showRoomList = !this.showRoomList;
    if (this.showRoomList) {
      await this.fetchRooms();
    }
  }

  async fetchRooms(): Promise<void> {
    try {
      let httpRequest = http.createHttp();
      httpRequest.on('headerReceive', (header: Object) => {
        console.info('Header received:', JSON.stringify(header));
      });
      let response = await httpRequest.request('http://192.168.189.217:8082/api/rooms', {
        method: http.RequestMethod.GET,
        connectTimeout: 60000,
        readTimeout: 60000
      });
      const data: RoomResponse = JSON.parse(response.result.toString()) as RoomResponse;
      this.rooms = data.rooms || [];
      httpRequest.destroy();
    } catch (error) {
      console.error('Fetch rooms error:', error);
      try {
        promptAction.showToast({ message: '获取房间列表失败' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    }
  }

  async joinRoom(roomId: string): Promise<void> {
    this.isLoading = true;
    try {
      await networkManager.connect();
      const sendData: SendData = {
        type: 'JOIN_ROOM',
        roomId: roomId,
        playerName: this.playerName
      };
      networkManager.send('JOIN_ROOM', sendData);
    } catch (error) {
      console.error('Join room error:', error);
      try {
        promptAction.showToast({ message: '加入房间失败' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      this.isLoading = false;
    }
  }
}
