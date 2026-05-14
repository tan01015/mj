import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct GameRoomPage {
  @State players: GamePlayer[] = [];
  @State isReady: boolean = false;
  @State allReady: boolean = false;
  @State isHost: boolean = false;
  @State mode: string = 'single';
  @State gameStarted: boolean = false;
  private unsubscribe: () => void = () => {};

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

    const params = router.getParams() as Record<string, string>;
    this.mode = params.mode || 'single';

    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.players = state.players;
      this.checkAllReady();
      this.checkIsHost();
    });

    if (this.mode === 'single') {
      this.startSinglePlayerGame();
    } else {
      this.setupMultiplayerListeners();
    }
  }

  aboutToDisappear() {
    this.unsubscribe();
  }

  build() {
    Stack() {
      // 背景装饰
      Row() {
        Text('🀄')
          .fontSize(180)
          .opacity(0.06)
          .rotate({ angle: -25 })
          .margin({ left: 150 })
        Blank()
        Text('🀅')
          .fontSize(150)
          .opacity(0.06)
          .rotate({ angle: 30 })
          .margin({ right: 200 })
      }
      .width('100%')
      .height('100%')

      // 主内容
      Row() {
        if (this.mode === 'multiplayer') {
          // 左侧控制面板
          Column() {
            Row() {
              Button('←')
                .fontSize(22)
                .width(50)
                .height(50)
                .backgroundColor('rgba(255, 255, 255, 0.15)')
                .fontColor('#fff')
                .borderRadius(25)
                .onClick(() => {
                  this.leaveRoom();
                })

              Blank()

              Text('房间')
                .fontSize(18)
                .fontColor('#ffffffcc')
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20 })

            Divider()
              .color('rgba(255, 255, 255, 0.15)')
              .margin({ top: 15 })

            // 房间信息
            Column() {
              Text(`房间ID`)
                .fontSize(14)
                .fontColor('#ffffff80')
              Text(gameManager.gameState.roomId)
                .fontSize(18)
                .fontColor('#fff')
                .fontWeight(FontWeight.Bold)
                .margin({ top: 5 })
            }
            .width('100%')
            .padding(20)
            .margin({ top: 15 })
            .backgroundColor('rgba(255, 255, 255, 0.08)')
            .borderRadius(10)

            Blank()

            // 操作按钮
            Column() {
              Button(this.isReady ? '取消准备' : '准备就绪')
                .width('90%')
                .height(55)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(this.isReady ? '#FF9800' : '#4CAF50')
                .fontColor('#ffffff')
                .borderRadius(28)
                .onClick(() => {
                  this.toggleReady();
                })

              if (this.canStartGame()) {
                Button('开始游戏')
                  .width('90%')
                  .height(55)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor('#2196F3')
                  .fontColor('#ffffff')
                  .borderRadius(28)
                  .margin({ top: 15 })
                  .onClick(() => {
                    this.startGame();
                  })
              }
            }
            .width('100%')
            .padding({ left: 15, right: 15, bottom: 30 })
          }
          .width('20%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.35)')
        }

        // 右侧玩家区域
        Column() {
          // 标题栏
          Row() {
            Blank()
            Text(this.mode === 'single' ? '🀄 单人对战' : '🌐 局域网对战')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fff')
            Blank()
          }
          .width('100%')
          .height(60)
          .padding({ top: 15 })
          .backgroundColor('rgba(0, 0, 0, 0.25)')

          // 玩家座位区域
          if (this.mode === 'multiplayer') {
            Row() {
              ForEach([0, 1, 2, 3], (seat: number) => {
                this.renderPlayerSeat(seat)
              }, (seat: number) => seat.toString())
            }
            .width('95%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.SpaceEvenly)
            .alignItems(VerticalAlign.Center)
          } else {
            // 单人模式
            Column() {
              Text('🤖')
                .fontSize(80)
                .margin({ bottom: 20 })

              Text('准备开始')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#fff')
                .margin({ bottom: 10 })

              Text('即将与AI对手进行对战')
                .fontSize(16)
                .fontColor('#ffffffcc')
                .margin({ bottom: 40 })

              if (!this.gameStarted) {
                LoadingProgress()
                  .width(70)
                  .height(70)
                  .color('#4CAF50')
              } else {
                Text('游戏加载中...')
                  .fontSize(16)
                  .fontColor('#4CAF50')
              }
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width(this.mode === 'multiplayer' ? '80%' : '100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  getPlayerColor(seat: number): string {
    const colors = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12'];
    return colors[seat % colors.length];
  }

  @Builder
  renderPlayerSeat(seat: number): void {
    Column() {
      if (this.players.find((p: GamePlayer) => p.seat === seat)) {
        Column() {
          Stack() {
            Circle()
              .width(80)
              .height(80)
              .fill(this.getPlayerColor(seat))

            Text(this.players.find((p: GamePlayer) => p.seat === seat)!.nickname.charAt(0).toUpperCase())
              .fontSize(32)
              .fontColor('#fff')
              .fontWeight(FontWeight.Bold)
          }
          .margin({ bottom: 12 })

          Text(this.players.find((p: GamePlayer) => p.seat === seat)!.nickname)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fff')
            .maxLines(1)
            .width(120)
            .textAlign(TextAlign.Center)

          Row() {
            Text(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '✓' : '○')
              .fontSize(16)
              .fontColor(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '#4CAF50' : '#95a5a6')
            Text(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '已准备' : '未准备')
              .fontSize(14)
              .fontColor(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '#4CAF50' : '#95a5a6')
              .margin({ left: 5 })
          }
          .margin({ top: 10 })
        }
      } else {
        Column() {
          Stack() {
            Circle()
              .width(80)
              .height(80)
              .fill('rgba(255, 255, 255, 0.1)')

            Text('?')
              .fontSize(32)
              .fontColor('#ffffff60')
          }
          .margin({ bottom: 12 })

          Text('等待加入')
            .fontSize(16)
            .fontColor('#ffffff60')
        }
      }
    }
    .width(150)
    .height(200)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255, 255, 255, 0.08)')
    .borderRadius(16)
  }

  startSinglePlayerGame(): void {
    gameManager.setRoomInfo('single-player', 'player-' + Date.now(), 0);

    const p0: GamePlayer = { seat: 0, nickname: '玩家', ready: true, online: true };
    const p1: GamePlayer = { seat: 1, nickname: 'AI-简单', ready: true, online: true };
    const p2: GamePlayer = { seat: 2, nickname: 'AI-中等', ready: true, online: true };
    const p3: GamePlayer = { seat: 3, nickname: 'AI-困难', ready: true, online: true };
    const aiPlayers: GamePlayer[] = [p0, p1, p2, p3];

    gameManager.updatePlayers(aiPlayers);
    gameManager.setSinglePlayerMode(true);

    // 单机模式不连服务器，直接本地启动
    setTimeout(() => {
      try {
        router.replaceUrl({
          url: 'pages/GamePage',
          params: { isSinglePlayer: 'true' }
        });
      } catch (e) {
        console.error('Router replace error:', e);
      }
    }, 500);
  }

  setupMultiplayerListeners(): void {
    networkManager.on('PLAYER_JOINED', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
        try {
          promptAction.showToast({ message: '新玩家加入' });
        } catch (e) {
          console.error('Show toast error:', e);
        }
      }
    });

    networkManager.on('PLAYER_LEFT', (msg: MessageData) => {
      try {
        promptAction.showToast({ message: '有玩家离开' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    });

    networkManager.on('READY_UPDATE', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('GAME_START', (msg: MessageData) => {
      console.info('Game starting:', msg);
      gameManager.setGameStarted(true);

      if (msg.hands) {
        const hands = msg.hands as Record<string, Array<number>>;
        const mySeat = gameManager.gameState.seat;
        const myHand = hands[String(mySeat)];
        if (myHand) {
          gameManager.updateMyHand(myHand);
        }
      }

      try {
        promptAction.showToast({ message: '游戏开始！' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      try {
        router.pushUrl({ url: 'pages/GamePage' });
      } catch (e) {
        console.error('Router push error:', e);
      }
    });

    networkManager.on('ERROR', (msg: MessageData) => {
      const message = msg.message ? String(msg.message) : '操作失败';
      try {
        promptAction.showToast({ message: message });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    });
  }

  toggleReady(): void {
    this.isReady = !this.isReady;
    const sendData: SendData = { type: 'READY', ready: this.isReady };
    networkManager.send('READY', sendData);
  }

  checkAllReady(): void {
    if (this.players.length >= 2) {
      this.allReady = this.players.every((p: GamePlayer) => p.ready);
    } else {
      this.allReady = false;
    }
  }

  checkIsHost(): void {
    this.isHost = gameManager.gameState.seat === 0;
  }

  canStartGame(): boolean {
    const state = gameManager.gameState;
    return state.players.length >= 2 &&
           this.allReady &&
           this.isHost;
  }

  startGame(): void {
    networkManager.send('START_GAME', { type: 'START_GAME' });
  }

  leaveRoom(): void {
    networkManager.disconnect();
    gameManager.reset();
    try {
      router.back();
    } catch (e) {
      console.error('Router back error:', e);
    }
  }
}
