import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct RoomPage {
  @State players: GamePlayer[] = [];
  @State isReady: boolean = false;
  @State allReady: boolean = false;
  @State isHost: boolean = false;
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

    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.players = state.players;
      this.checkAllReady();
      this.checkIsHost();
    });

    networkManager.on('PLAYER_JOINED', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('READY_UPDATE', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('GAME_START', (msg: MessageData) => {
      console.info('RoomPage received GAME_START:', JSON.stringify(msg));
      gameManager.setGameStarted(true);

      // 在跳转前把游戏数据存入 GameManager，GamePage 初始化时直接读取
      if (msg.hands) {
        const hands = msg.hands as Record<string, Array<number>>;
        const mySeat = gameManager.gameState.seat;
        const myHand = hands[String(mySeat)];
        if (myHand) {
          gameManager.updateMyHand(myHand);
        }
        gameManager.syncMultiplayerHands(hands);
      }
      if (msg.currentPlayer !== undefined) {
        gameManager.updateCurrentPlayer(Number(msg.currentPlayer));
      }
      if (msg.remainingTiles !== undefined) {
        gameManager.updateRemainingTiles(Number(msg.remainingTiles));
      }
      if (msg.dealerSeat !== undefined) {
        gameManager.updateRoundInfo(Number(msg.dealerSeat), 1);
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
                networkManager.disconnect();
                gameManager.reset();
                try {
                  router.back();
                } catch (e) {
                  console.error('Router back error:', e);
                }
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

        // 右侧玩家区域
        Column() {
          // 标题栏
          Row() {
            Text('🌐 游戏房间')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fff')

            Blank()

            Text(`房间ID: ${gameManager.gameState.roomId}`)
              .fontSize(16)
              .fontColor('#ffffff80')
              .padding({ right: 25 })
          }
          .width('100%')
          .height(65)
          .padding({ top: 15 })
          .backgroundColor('rgba(0, 0, 0, 0.25)')

          // 玩家座位区域
          Row() {
            ForEach([0, 1, 2, 3], (seat: number) => {
              this.renderPlayerSeat(seat)
            }, (seat: number) => seat.toString())
          }
          .width('95%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.SpaceEvenly)
          .alignItems(VerticalAlign.Center)
        }
        .width('80%')
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

  toggleReady(): void {
    this.isReady = !this.isReady;
    const sendData: SendData = { type: 'READY', ready: this.isReady };
    networkManager.send('READY', sendData);
  }

  checkAllReady(): void {
    this.allReady = this.players.length > 0 && this.players.every((p: GamePlayer) => p.ready);
  }

  checkIsHost(): void {
    this.isHost = gameManager.gameState.seat === 0;
  }

  canStartGame(): boolean {
    const state = gameManager.gameState;
    return state.players.length >= 2 && this.allReady && this.isHost;
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

  startGame(): void {
    networkManager.send('START_GAME', { type: 'START_GAME' });
  }
}
