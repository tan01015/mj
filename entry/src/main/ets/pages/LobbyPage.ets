import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
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
  @State serverIp: string = '192.168.189.217';
  @State serverPort: string = '8082';
  @State playerName: string = '';
  @State rooms: RoomInfo[] = [];
  @State isLoading: boolean = false;
  @State showRoomList: boolean = false;
  @State isConnected: boolean = false;

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

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
    // 不在这里断开连接，因为可能要跳转到 RoomPage
  }

  build() {
    Stack() {
      // 背景装饰
      Row() {
        Text('🀄')
          .fontSize(150)
          .opacity(0.08)
          .rotate({ angle: -20 })
          .margin({ left: 100 })
        Blank()
        Text('🀅')
          .fontSize(120)
          .opacity(0.08)
          .rotate({ angle: 25 })
          .margin({ right: 150 })
      }
      .width('100%')
      .height('100%')

      // 主内容
      Row() {
        // 左侧控制面板
        Scroll() {
          Column() {
            // 标题
            Row() {
              Button('←')
                .fontSize(22)
                .width(50)
                .height(50)
                .backgroundColor('rgba(255, 255, 255, 0.15)')
                .fontColor('#fff')
                .borderRadius(25)
                .onClick(() => {
                  networkManager.disconnect();
                  try {
                    router.back();
                  } catch (e) {
                    console.error('Router back error:', e);
                  }
                })

              Blank()

              Text('🌐 局域网对战')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#fff')

              Blank()

              Text('')
                .width(50)
            }
            .width('100%')
            .padding({ left: 25, right: 25, top: 15, bottom: 20 })

            Divider().color('rgba(255, 255, 255, 0.15)')

            // 服务器连接区域
            Column() {
              Text('服务器连接')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#fff')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 15 })

              Row({ space: 10 }) {
                TextInput({ placeholder: '服务器IP', text: this.serverIp })
                  .fontSize(15)
                  .backgroundColor('rgba(255, 255, 255, 0.9)')
                  .borderRadius(8)
                  .height(50)
                  .layoutWeight(3)
                  .onChange((value: string) => {
                    this.serverIp = value;
                  })

                TextInput({ placeholder: '端口', text: this.serverPort })
                  .fontSize(15)
                  .backgroundColor('rgba(255, 255, 255, 0.9)')
                  .borderRadius(8)
                  .height(50)
                  .width(100)
                  .onChange((value: string) => {
                    this.serverPort = value;
                  })
              }
              .width('100%')

              Button(this.isConnected ? '✓ 已连接' : '连接服务器')
                .width('100%')
                .height(50)
                .fontSize(17)
                .backgroundColor(this.isConnected ? '#4CAF50' : '#FF9800')
                .fontColor('#fff')
                .borderRadius(8)
                .margin({ top: 15 })
                .enabled(!this.isLoading)
                .onClick(() => {
                  this.connectToServer();
                })
            }
            .width('100%')
            .padding(25)
            .backgroundColor('rgba(255, 255, 255, 0.08)')
            .borderRadius(12)
            .margin({ top: 20 })

            // 房间操作区域
            if (this.isConnected) {
              Column() {
                Text('房间操作')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#fff')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 15 })

                TextInput({ placeholder: '请输入您的昵称' })
                  .width('100%')
                  .height(50)
                  .fontSize(15)
                  .backgroundColor('rgba(255, 255, 255, 0.9)')
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.playerName = value;
                  })
                  .onSubmit(() => {
                    this.createRoom();
                  })

                Row({ space: 15 }) {
                  Button('创建房间')
                    .layoutWeight(1)
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#4CAF50')
                    .fontColor('#fff')
                    .borderRadius(8)
                    .margin({ top: 15 })
                    .enabled(!this.isLoading)
                    .onClick(() => {
                      this.createRoom();
                    })

                  Button('加入房间')
                    .layoutWeight(1)
                    .height(50)
                    .fontSize(16)
                    .backgroundColor('#2196F3')
                    .fontColor('#fff')
                    .borderRadius(8)
                    .margin({ top: 15 })
                    .enabled(!this.isLoading)
                    .onClick(() => {
                      this.toggleRoomList();
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(25)
              .backgroundColor('rgba(255, 255, 255, 0.08)')
              .borderRadius(12)
              .margin({ top: 20 })
            }
          }
          .width('100%')
          .padding(25)
        }
        .width('50%')
        .height('100%')
        .scrollBar(BarState.Auto)
        .scrollBarColor('rgba(255, 255, 255, 0.3)')
        .scrollBarWidth(6)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor('rgba(0, 0, 0, 0.3)')

        // 右侧房间列表
        if (this.showRoomList) {
          Column() {
            Row() {
              Text('房间列表')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#fff')

              Blank()

              Button('刷新')
                .fontSize(15)
                .height(40)
                .width(80)
                .backgroundColor('rgba(255, 255, 255, 0.15)')
                .fontColor('#fff')
                .borderRadius(20)
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
                        Text(`房间 ${room.roomId}`)
                          .fontSize(18)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#fff')
                        Text(`${room.playersCount}/${room.maxPlayers} 人`)
                          .fontSize(14)
                          .fontColor('#ffffffcc')
                          .margin({ top: 5 })
                      }
                      .alignItems(HorizontalAlign.Start)

                      Blank()

                      if (room.gameStarted) {
                        Text('游戏中')
                          .fontSize(14)
                          .fontColor('#FF9800')
                          .margin({ right: 15 })
                      } else {
                        Button('加入')
                          .fontSize(15)
                          .height(40)
                          .width(80)
                          .backgroundColor('#2196F3')
                          .fontColor('#fff')
                          .borderRadius(20)
                          .enabled(!room.gameStarted && room.playersCount < room.maxPlayers)
                          .onClick(() => {
                            this.joinRoom(room.roomId);
                          })
                      }
                    }
                    .width('100%')
                    .padding(18)
                    .backgroundColor('rgba(255, 255, 255, 0.1)')
                    .borderRadius(10)
                  }
                }, (room: RoomInfo) => room.roomId)
              }
              .width('100%')
              .layoutWeight(1)
            } else {
              Column() {
                Text('🀄')
                  .fontSize(60)
                  .opacity(0.5)
                Text('暂无房间')
                  .fontSize(18)
                  .fontColor('#ffffff80')
                  .margin({ top: 15 })
                Text('点击"创建房间"开始游戏')
                  .fontSize(14)
                  .fontColor('#ffffff60')
                  .margin({ top: 8 })
              }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('50%')
          .height('100%')
          .padding({ left: 30, right: 30, top: 20, bottom: 20 })
        } else {
          // 未显示房间列表时的提示
          Column() {
            Text('🀄')
              .fontSize(100)
              .opacity(0.3)
            Text('连接服务器后创建或加入房间')
              .fontSize(18)
              .fontColor('#ffffff80')
              .margin({ top: 20 })
          }
          .width('50%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  // 连接服务器
  async connectToServer(): Promise<void> {
    if (this.isConnected) {
      networkManager.disconnect();
      this.isConnected = false;
      try {
        promptAction.showToast({ message: '已断开连接' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    if (!this.serverIp.trim()) {
      try {
        promptAction.showToast({ message: '请输入服务器IP地址' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    this.isLoading = true;
    const host = `${this.serverIp.trim()}:${this.serverPort.trim() || '8082'}`;
    networkManager.setServerHost(host);
    console.info('正在连接服务器:', host);

    try {
      await networkManager.connect();
      this.isConnected = true;
      try {
        promptAction.showToast({ message: '服务器连接成功' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    } catch (error) {
      console.error('连接服务器失败:', error);
      this.isConnected = false;
      try {
        promptAction.showToast({ message: '连接服务器失败，请检查IP和端口' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    } finally {
      this.isLoading = false;
    }
  }

  // 创建房间
  async createRoom(): Promise<void> {
    if (!this.playerName.trim()) {
      try {
        promptAction.showToast({ message: '请输入昵称' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    if (!this.isConnected) {
      try {
        promptAction.showToast({ message: '请先连接服务器' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      return;
    }

    this.isLoading = true;
    const sendData: SendData = {
      type: 'CREATE_ROOM',
      playerName: this.playerName,
      gameMode: 'standard',
      maxPlayers: 4
    };
    networkManager.send('CREATE_ROOM', sendData);
  }

  // 切换房间列表
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

  // 获取房间列表
  async fetchRooms(): Promise<void> {
    try {
      let httpRequest = http.createHttp();
      const url = `${networkManager.httpBaseUrl}/api/rooms`;
      console.info('获取房间列表:', url);
      let response = await httpRequest.request(url, {
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

  // 加入房间
  async joinRoom(roomId: string): Promise<void> {
    this.isLoading = true;
    const sendData: SendData = {
      type: 'JOIN_ROOM',
      roomId: roomId,
      playerName: this.playerName
    };
    networkManager.send('JOIN_ROOM', sendData);
  }
}
